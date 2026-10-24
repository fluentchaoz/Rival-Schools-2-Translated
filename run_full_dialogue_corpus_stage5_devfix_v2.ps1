param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail "$Command failed with exit code $LASTEXITCODE"
    }
}

function Replace-RegexOnce(
    [string]$Text,
    [string]$Pattern,
    [string]$Replacement,
    [string]$Description
) {
    $regex = New-Object System.Text.RegularExpressions.Regex(
        $Pattern,
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $matches = $regex.Matches($Text)
    if ($matches.Count -ne 1) {
        Fail "$Description: expected exactly one match, found $($matches.Count)."
    }
    return $regex.Replace($Text, $Replacement, 1)
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$DevCodebookInput = Join-Path $Here "justice_gakuen_dev_complete_codebook_stage5.json"
$PlaceholderMapInput = Join-Path $Here "justice_gakuen_dev_placeholder_map_stage5.json"
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder." }
if (-not (Test-Path $DevCodebookInput)) {
    Fail "Missing justice_gakuen_dev_complete_codebook_stage5.json beside this script."
}
if (-not (Test-Path $PlaceholderMapInput)) {
    Fail "Missing justice_gakuen_dev_placeholder_map_stage5.json beside this script."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not on PATH."
}

$bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
if ($bins.Count -ne 1) {
    Fail "Expected exactly one .bin in $RomFolder; found $($bins.Count)."
}

$SourceBin = $bins[0].FullName
$SourceHash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
Write-Host "Source BIN SHA-256: $SourceHash"
if ($SourceHash -ne $ExpectedBinHash) {
    Fail "This is not the exact BIN we audited."
}

$Roms = Join-Path $Upstream "roms"
New-Item -ItemType Directory -Force -Path $Roms | Out-Null
$TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

if (-not (Test-Path $TargetBin) -or
    (Get-FileHash -Algorithm SHA256 $TargetBin).Hash.ToLower() -ne $ExpectedBinHash) {
    Copy-Item $SourceBin $TargetBin -Force
}

@'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $TargetCue

# Preserve/install the Windows 64 MB worker-stack fix.
$MainRs = Join-Path $Upstream "src\main.rs"
$mainText = [System.IO.File]::ReadAllText($MainRs)
$StackMarker = "justice-gakuen2-large-stack"

if (-not $mainText.Contains($StackMarker)) {
    $oldMain = "fn main() -> Result<()> {"
    $count = ([regex]::Matches($mainText, [regex]::Escape($oldMain))).Count
    if ($count -ne 1) {
        Fail "Could not safely patch Rust main() for a larger stack."
    }

    $mainText = $mainText.Replace($oldMain, "fn app_main() -> Result<()> {")
    $wrapper = @'

fn main() -> Result<()> {
    let worker = std::thread::Builder::new()
        .name("justice-gakuen2-large-stack".to_string())
        .stack_size(64 * 1024 * 1024)
        .spawn(app_main)?;

    match worker.join() {
        Ok(result) => result,
        Err(payload) => std::panic::resume_unwind(payload),
    }
}
'@
    [System.IO.File]::WriteAllText(
        $MainRs,
        $mainText + $wrapper,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

# ---------------------------------------------------------------------------
# Development-only PUA semantic patch.
#
# We keep all raw/structural denominators and exact per-entry word roundtrip.
# The only deferred invariant is the canonical semantic-group count because
# unique PUA placeholders intentionally keep unresolved pixel identities
# distinct instead of pretending that two hashes mean the same Japanese glyph.
# ---------------------------------------------------------------------------
$CorpusRs = Join-Path $Upstream "src\dialogue_audit\corpus.rs"
if (-not (Test-Path $CorpusRs)) {
    Fail "Missing src\dialogue_audit\corpus.rs"
}

$corpus = [System.IO.File]::ReadAllText($CorpusRs)
$Marker = "ENGLISH_PROJECT_DEVELOPMENT_PUA_SEMANTICS"

if (-not $corpus.Contains($Marker)) {
    $loadPattern = 'let\s+\(codebook_sha256,\s*glyphs\)\s*=\s*load_resolved_dialogue_glyphs\(\s*codebook_path,\s*source_bin_sha256,\s*&source_pixel_hashes,\s*&usage,\s*\)\?;'
    $loadReplacement = @'
let (codebook_sha256, glyphs) = load_resolved_dialogue_glyphs(
        codebook_path,
        source_bin_sha256,
        &source_pixel_hashes,
        &usage,
    )?;

    // ENGLISH_PROJECT_DEVELOPMENT_PUA_SEMANTICS:
    // PUA text preserves unresolved source-glyph identity but deliberately does
    // not claim Japanese semantic equivalence between distinct pixel hashes.
    let contains_development_pua_placeholders = glyphs.values().any(|glyph| {
        glyph
            .text
            .chars()
            .any(|character| ('\u{e000}'..='\u{f8ff}').contains(&character))
    });
'@

    $corpus = Replace-RegexOnce `
        $corpus `
        $loadPattern `
        $loadReplacement `
        "Could not locate resolved-codebook load block"

    $semanticPattern = 'ensure!\(\s*semantic_counts\.len\(\)\s*==\s*denominators\.semantic_shared_group_count,\s*"dialogue semantic-group denominator changed"\s*\);'
    $semanticReplacement = @'
if !contains_development_pua_placeholders {
        ensure!(
            semantic_counts.len() == denominators.semantic_shared_group_count,
            "dialogue semantic-group denominator changed"
        );
    }
'@

    $corpus = Replace-RegexOnce `
        $corpus `
        $semanticPattern `
        $semanticReplacement `
        "Could not locate semantic-group denominator gate"

    $readyPattern = 'ready_for_translation:\s*true,'
    $readyReplacement = 'ready_for_translation: !contains_development_pua_placeholders,'

    $corpus = Replace-RegexOnce `
        $corpus `
        $readyPattern `
        $readyReplacement `
        "Could not locate ready_for_translation field"

    [System.IO.File]::WriteAllText(
        $CorpusRs,
        $corpus,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Host "Installed robust development-PUA corpus patch." -ForegroundColor Cyan
}
else {
    Write-Host "Development-PUA corpus patch already installed." -ForegroundColor Cyan
}

$Work = Join-Path $Upstream "work"
$CodebookDir = Join-Path $Work "english-development-corpus"
$DevCodebook = Join-Path $CodebookDir "dev-complete-codebook.json"
$PlaceholderMap = Join-Path $CodebookDir "placeholder-map.json"
$Audit = Join-Path $CodebookDir "dev-codebook-audit.json"
$CorpusDir = Join-Path $CodebookDir "full-source-corpus"
$PackageDir = Join-Path $Work "english-full-corpus-package"
$Zip = Join-Path $Work "english-full-source-corpus-stage5-devfix-v2.zip"

if (Test-Path $CodebookDir) {
    Remove-Item $CodebookDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $CodebookDir | Out-Null

Copy-Item $DevCodebookInput $DevCodebook
Copy-Item $PlaceholderMapInput $PlaceholderMap

foreach ($Path in @($DevCodebook, $PlaceholderMap)) {
    $txt = [System.IO.File]::ReadAllText($Path)
    [System.IO.File]::WriteAllText(
        $Path,
        $txt,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

Write-Host ""
Write-Host "Justice Gakuen English Project - Full Development Corpus Dump v2" -ForegroundColor Cyan
Write-Host ""
Write-Host "Known Japanese glyph hashes: 768"
Write-Host "Identity-preserving PUA placeholders: 915"
Write-Host "Total source glyph identities: 1683"

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/4] Building extractor..."
    Run-Native "cargo" @("build", "--release")

    $Exe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    if (-not (Test-Path $Exe)) {
        Fail "Release executable was not produced."
    }

    Write-Host ""
    Write-Host "[2/4] Auditing development-complete 1683-entry codebook..."
    Run-Native $Exe @(
        "audit-dialogue-codebook",
        "--cue", $TargetCue,
        "--codebook", $DevCodebook,
        "--output", $Audit
    )

    $AuditObj = Get-Content $Audit -Raw | ConvertFrom-Json
    Write-Host "  Verified entries: $($AuditObj.verified_entry_count)"
    Write-Host "  Unresolved used glyph hashes: $($AuditObj.unresolved_used_source_pixel_hash_count)"

    if ($AuditObj.verified_entry_count -ne 1683) {
        Fail "Expected 1683 development-resolved entries; got $($AuditObj.verified_entry_count)."
    }
    if ($AuditObj.unresolved_used_source_pixel_hash_count -ne 0) {
        Fail "Development codebook still has unresolved glyph hashes."
    }

    if (Test-Path $CorpusDir) {
        Remove-Item $CorpusDir -Recurse -Force
    }

    Write-Host ""
    Write-Host "[3/4] Extracting all dialogue coordinates..."
    Run-Native $Exe @(
        "build-dialogue-source-corpus",
        "--cue", $TargetCue,
        "--codebook", $DevCodebook,
        "--output-dir", $CorpusDir
    )
}
finally {
    Pop-Location
}

$Manifest = Join-Path $CorpusDir "dialogue-source-corpus.json"
if (-not (Test-Path $Manifest)) {
    Fail "Full dialogue corpus manifest was not produced."
}

$ManifestObj = Get-Content $Manifest -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "Corpus results:" -ForegroundColor Cyan
Write-Host "  Assets: $($ManifestObj.asset_count)"
Write-Host "  Banks: $($ManifestObj.bank_count)"
Write-Host "  Shards: $($ManifestObj.shard_count)"
Write-Host "  Coordinates: $($ManifestObj.coordinate_count)"
Write-Host "  Unique raw entries: $($ManifestObj.raw_unique_entry_count)"
Write-Host "  Provisional semantic groups: $($ManifestObj.semantic_shared_group_count)"
Write-Host "  Glyph occurrences: $($ManifestObj.glyph_occurrence_count)"
Write-Host "  Control occurrences: $($ManifestObj.control_occurrence_count)"
Write-Host "  Padding words: $($ManifestObj.alignment_padding_word_count)"
Write-Host "  Roundtrip verified coordinates: $($ManifestObj.roundtrip_verified_coordinate_count)"
Write-Host "  Ready for translation: $($ManifestObj.ready_for_translation)"

# Raw/structural invariants remain strict.
if ($ManifestObj.asset_count -ne 78) {
    Fail "Expected 78 dialogue assets."
}
if ($ManifestObj.coordinate_count -ne 62639) {
    Fail "Expected 62639 dialogue coordinates."
}
if ($ManifestObj.raw_unique_entry_count -ne 42681) {
    Fail "Expected 42681 unique raw entries."
}
if ($ManifestObj.glyph_occurrence_count -ne 1539426) {
    Fail "Glyph occurrence denominator changed."
}
if ($ManifestObj.control_occurrence_count -ne 218286) {
    Fail "Control occurrence denominator changed."
}
if ($ManifestObj.alignment_padding_word_count -ne 32787) {
    Fail "Alignment-padding denominator changed."
}
if ($ManifestObj.roundtrip_verified_coordinate_count -ne 62639) {
    Fail "Not every dialogue coordinate round-tripped to its original words."
}
if ($ManifestObj.ready_for_translation -ne $false) {
    Fail "PUA development corpus must remain explicitly not-ready-for-translation."
}

if (Test-Path $PackageDir) {
    Remove-Item $PackageDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null

Copy-Item $DevCodebook (Join-Path $PackageDir "dev-complete-codebook.json")
Copy-Item $PlaceholderMap (Join-Path $PackageDir "placeholder-map.json")
Copy-Item $Audit (Join-Path $PackageDir "dev-codebook-audit.json")
Copy-Item $CorpusDir (Join-Path $PackageDir "full-source-corpus") -Recurse

$Readme = Join-Path $PackageDir "DEVELOPMENT-CORPUS-NOTE.txt"
$note = @'
Justice Gakuen 2 English Project - development corpus

This corpus preserves all source dialogue coordinates and raw words exactly.
Every one of the 62,639 coordinates must pass exact reconstruction.

U+E000..U+E392 are identity-preserving placeholders for 915 source
glyph hashes whose Japanese meanings have not yet been resolved.

Because these unique placeholders deliberately avoid claiming false semantic
equivalence between unresolved pixel hashes, semantic_shared_group_count is
PROVISIONAL and ready_for_translation is false.

The final release corpus must restore the canonical 18,807 semantic-group
denominator after all source glyph meanings are resolved.
'@
[System.IO.File]::WriteAllText(
    $Readme,
    $note,
    (New-Object System.Text.UTF8Encoding($false))
)

if (Test-Path $Zip) {
    Remove-Item $Zip -Force
}

Write-Host ""
Write-Host "[4/4] Packaging full development corpus..."
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Zip -CompressionLevel Optimal

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "FULL DEVELOPMENT DIALOGUE CORPUS EXTRACTED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload this ZIP back to ChatGPT:" -ForegroundColor Yellow
Write-Host $Zip -ForegroundColor Yellow

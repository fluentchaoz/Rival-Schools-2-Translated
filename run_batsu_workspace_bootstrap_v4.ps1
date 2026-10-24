param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder,

    [Parameter(Mandatory=$false)]
    [string]$BatsuPackage = ""
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

function Read-Utf8Text([string]$Path) {
    return [System.IO.File]::ReadAllText(
        $Path,
        (New-Object System.Text.UTF8Encoding($false, $true))
    )
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
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
        Fail ("{0}: expected exactly one match, found {1}" -f $Description, $matches.Count)
    }
    return $regex.Replace($Text, $Replacement, 1)
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder beside this script."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not on PATH."
}

# Locate the Batsu translation ZIP the user already downloaded.
if ([string]::IsNullOrWhiteSpace($BatsuPackage)) {
    $candidates = @(
        (Join-Path $Here "justice_gakuen_batsu_translation_v1.zip"),
        (Join-Path (Split-Path $Here -Parent) "justice_gakuen_batsu_translation_v1.zip"),
        (Join-Path $env:USERPROFILE "Downloads\justice_gakuen_batsu_translation_v1.zip")
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $BatsuPackage = $candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($BatsuPackage) -or -not (Test-Path $BatsuPackage)) {
    Fail "Could not find justice_gakuen_batsu_translation_v1.zip. Put it beside this script or pass -BatsuPackage."
}

# Validate the exact audited source BIN.
$bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
if ($bins.Count -ne 1) {
    Fail ("Expected exactly one .bin in {0}; found {1}" -f $RomFolder, $bins.Count)
}
$SourceBin = $bins[0].FullName
$SourceHash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
Write-Host ("Source BIN SHA-256: {0}" -f $SourceHash)
if ($SourceHash -ne $ExpectedBinHash) {
    Fail "This is not the exact BIN we audited."
}

# Re-establish the upstream ROM path expected by the toolchain.
$Roms = Join-Path $Upstream "roms"
New-Item -ItemType Directory -Force -Path $Roms | Out-Null
$TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

if (-not (Test-Path $TargetBin) -or
    (Get-FileHash -Algorithm SHA256 $TargetBin).Hash.ToLower() -ne $ExpectedBinHash) {
    Copy-Item $SourceBin $TargetBin -Force
}

$cueText = @'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@
[System.IO.File]::WriteAllText($TargetCue, $cueText, [System.Text.Encoding]::ASCII)

# Preserve/install the 64 MiB Windows worker-stack wrapper.
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
    Write-Utf8NoBom $MainRs ($mainText + $wrapper)
}

# Ensure the development-PUA corpus patch is present.
$CorpusRs = Join-Path $Upstream "src\dialogue_audit\corpus.rs"
if (-not (Test-Path $CorpusRs)) {
    Fail "Missing src\dialogue_audit\corpus.rs"
}
$corpus = [System.IO.File]::ReadAllText($CorpusRs)
$CorpusMarker = "ENGLISH_PROJECT_DEVELOPMENT_PUA_SEMANTICS"

if (-not $corpus.Contains($CorpusMarker)) {
    $loadPattern = 'let\s+\(codebook_sha256,\s*glyphs\)\s*=\s*load_resolved_dialogue_glyphs\(\s*codebook_path,\s*source_bin_sha256,\s*&source_pixel_hashes,\s*&usage,\s*\)\?;'
    $loadReplacement = @'
let (codebook_sha256, glyphs) = load_resolved_dialogue_glyphs(
        codebook_path,
        source_bin_sha256,
        &source_pixel_hashes,
        &usage,
    )?;

    // ENGLISH_PROJECT_DEVELOPMENT_PUA_SEMANTICS:
    // PUA text preserves unresolved source-glyph identity without claiming
    // Japanese semantic equivalence between distinct pixel hashes.
    let contains_development_pua_placeholders = glyphs.values().any(|glyph| {
        glyph
            .text
            .chars()
            .any(|character| ('\u{e000}'..='\u{f8ff}').contains(&character))
    });
'@
    $corpus = Replace-RegexOnce $corpus $loadPattern $loadReplacement "Corpus resolved-codebook load block"

    $semanticPattern = 'ensure!\(\s*semantic_counts\.len\(\)\s*==\s*denominators\.semantic_shared_group_count,\s*"dialogue semantic-group denominator changed"\s*\);'
    $semanticReplacement = @'
if !contains_development_pua_placeholders {
        ensure!(
            semantic_counts.len() == denominators.semantic_shared_group_count,
            "dialogue semantic-group denominator changed"
        );
    }
'@
    $corpus = Replace-RegexOnce $corpus $semanticPattern $semanticReplacement "Corpus semantic-group denominator gate"

    $readyPattern = 'ready_for_translation:\s*true,'
    $readyReplacement = 'ready_for_translation: !contains_development_pua_placeholders,'
    $corpus = Replace-RegexOnce $corpus $readyPattern $readyReplacement "Corpus ready_for_translation field"

    Write-Utf8NoBom $CorpusRs $corpus
    Write-Host "Installed development-PUA corpus patch." -ForegroundColor Cyan
}

# Let the resolved-primary workspace use the exact structural population while
# semantic-group normalization is still provisional under PUA placeholders.
$WorkspaceSourceRs = Join-Path $Upstream "src\dialogue_audit\translation_workspace_source.rs"
if (-not (Test-Path $WorkspaceSourceRs)) {
    Fail "Missing src\dialogue_audit\translation_workspace_source.rs"
}
$workspaceSource = [System.IO.File]::ReadAllText($WorkspaceSourceRs)
$WorkspaceMarker = "ENGLISH_PROJECT_DEVELOPMENT_PUA_WORKSPACE_DENOMINATOR"

if (-not $workspaceSource.Contains($WorkspaceMarker)) {
    $workspaceGatePattern = 'ensure!\(\s*\(\s*audits\.len\(\),\s*semantic_group_count,\s*referenced_coordinates\.len\(\)\s*\)\s*==\s*expected_denominator,\s*"translation workspace source denominator changed: assets=\{\}, groups=\{semantic_group_count\}, coordinates=\{\}",\s*audits\.len\(\),\s*referenced_coordinates\.len\(\)\s*\);'
    $workspaceGateReplacement = @'
// ENGLISH_PROJECT_DEVELOPMENT_PUA_WORKSPACE_DENOMINATOR:
// Keep asset and referenced-coordinate denominators strict. The semantic-group
// count remains provisional only while the development corpus contains PUA
// identity placeholders.
    if corpus.ready_for_translation {
        ensure!(
            (
                audits.len(),
                semantic_group_count,
                referenced_coordinates.len()
            ) == expected_denominator,
            "translation workspace source denominator changed: assets={}, groups={semantic_group_count}, coordinates={}",
            audits.len(),
            referenced_coordinates.len()
        );
    } else {
        ensure!(
            audits.len() == expected_denominator.0
                && referenced_coordinates.len() == expected_denominator.2,
            "translation workspace structural denominator changed under development PUA semantics: assets={}, groups={semantic_group_count}, coordinates={}",
            audits.len(),
            referenced_coordinates.len()
        );
    }
'@
    $workspaceSource = Replace-RegexOnce `
        $workspaceSource `
        $workspaceGatePattern `
        $workspaceGateReplacement `
        "Translation workspace denominator gate"

    Write-Utf8NoBom $WorkspaceSourceRs $workspaceSource
    Write-Host "Installed development-PUA workspace denominator patch." -ForegroundColor Cyan
}

# Prepare owned work paths.
$WorkRoot = Join-Path $Upstream "work\english-batsu-bootstrap"
$PackageExtract = Join-Path $WorkRoot "package"
$Workspace = Join-Path $WorkRoot "translation-workspace"
$Codebook = Join-Path $WorkRoot "batsu-codebook.json"
$Audit = Join-Path $WorkRoot "translation-audit.json"
$ImportReport = Join-Path $WorkRoot "batsu-import-report.json"
$OutputZip = Join-Path $Upstream "work\english-batsu-workspace-bootstrap-v4.zip"

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PackageExtract | Out-Null

Expand-Archive -Path $BatsuPackage -DestinationPath $PackageExtract -Force

$RouteTranslation = Join-Path $PackageExtract "justice_gakuen_batsu_route_translation_v1.json"
$ResolvedCodebook = Join-Path $PackageExtract "justice_gakuen_batsu_resolved_dev_codebook_v1.json"

if (-not (Test-Path $RouteTranslation)) {
    Fail "Batsu package is missing justice_gakuen_batsu_route_translation_v1.json"
}
if (-not (Test-Path $ResolvedCodebook)) {
    Fail "Batsu package is missing justice_gakuen_batsu_resolved_dev_codebook_v1.json"
}

Copy-Item $ResolvedCodebook $Codebook -Force

# Canonicalize the Batsu codebook evidence arrays before Rust validation.
# The Batsu package appended a new evidence ID to several already-verified entries;
# Rust requires each evidence list to be nonempty, unique, and lexicographically ascending.
$CodebookObj = (Read-Utf8Text $Codebook) | ConvertFrom-Json

if ($null -eq $CodebookObj.entries -or $null -eq $CodebookObj.evidence_sources) {
    Fail "Batsu resolved codebook is missing entries or evidence_sources."
}

$EvidenceSourceIds = @($CodebookObj.evidence_sources.PSObject.Properties.Name)
$NormalizedEvidenceEntryCount = 0

foreach ($Entry in @($CodebookObj.entries)) {
    $OriginalEvidence = @($Entry.evidence | ForEach-Object { [string]$_ })

    if ($OriginalEvidence.Count -eq 0) {
        Fail ("Codebook entry {0} has an empty evidence list." -f $Entry.pixel_sha256)
    }

    foreach ($EvidenceId in $OriginalEvidence) {
        if ($EvidenceSourceIds -notcontains $EvidenceId) {
            Fail (
                "Codebook entry {0} references unknown evidence source {1}." -f
                $Entry.pixel_sha256, $EvidenceId
            )
        }
    }

    $CanonicalEvidence = @($OriginalEvidence | Sort-Object -Unique)

    $OriginalKey = ($OriginalEvidence -join "`0")
    $CanonicalKey = ($CanonicalEvidence -join "`0")
    if ($OriginalKey -ne $CanonicalKey) {
        $NormalizedEvidenceEntryCount += 1
    }

    $Entry.evidence = @($CanonicalEvidence)
}

# Also confirm source entries remain strictly ascending and unique by pixel hash.
$PreviousPixelHash = $null
foreach ($Entry in @($CodebookObj.entries)) {
    $CurrentPixelHash = [string]$Entry.pixel_sha256

    if ($null -ne $PreviousPixelHash -and
        [string]::CompareOrdinal($PreviousPixelHash, $CurrentPixelHash) -ge 0) {
        Fail "Batsu codebook pixel_sha256 entries are not strictly ascending and unique."
    }

    $PreviousPixelHash = $CurrentPixelHash
}

# Sanity-check every character meaning before serializing. All source character
# meanings currently used by this project are BMP scalars (Japanese, ASCII, PUA),
# so a .NET string length other than 1 here is concrete evidence of encoding damage.
$CharacterMeaningCount = 0
foreach ($Entry in @($CodebookObj.entries)) {
    if ([string]$Entry.meaning.kind -ne "character") {
        continue
    }

    $CharacterMeaningCount += 1
    $MeaningText = [string]$Entry.meaning.text

    if ($MeaningText.Length -ne 1 -or [char]::IsControl($MeaningText[0])) {
        $CodeUnits = @(
            $MeaningText.ToCharArray() |
                ForEach-Object { ("U+{0:X4}" -f [int][char]$_) }
        ) -join ","

        Fail (
            "Unicode corruption detected before Rust audit at {0}: text='{1}', UTF-16={2}" -f
            $Entry.pixel_sha256, $MeaningText, $CodeUnits
        )
    }
}

$CanonicalCodebookJson = $CodebookObj | ConvertTo-Json -Depth 100
Write-Utf8NoBom $Codebook ($CanonicalCodebookJson + [Environment]::NewLine)

# Read the just-written file back as strict UTF-8 and repeat the scalar check.
$RoundtripCodebookObj = (Read-Utf8Text $Codebook) | ConvertFrom-Json
foreach ($Entry in @($RoundtripCodebookObj.entries)) {
    if ([string]$Entry.meaning.kind -ne "character") {
        continue
    }

    $MeaningText = [string]$Entry.meaning.text
    if ($MeaningText.Length -ne 1 -or [char]::IsControl($MeaningText[0])) {
        Fail (
            "Unicode corruption detected after UTF-8 codebook roundtrip at {0}" -f
            $Entry.pixel_sha256
        )
    }
}

Write-Host ("Character meanings UTF-8 verified: {0}" -f $CharacterMeaningCount) -ForegroundColor Cyan

Write-Host (
    "Normalized codebook evidence arrays: {0} entr{1}" -f
    $NormalizedEvidenceEntryCount,
    $(if ($NormalizedEvidenceEntryCount -eq 1) { "y" } else { "ies" })
) -ForegroundColor Cyan

Write-Host ""
Write-Host "Justice Gakuen English Project - Batsu Workspace Bootstrap v4" -ForegroundColor Cyan

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/5] Building patched extractor/workspace tools..."
    Run-Native "cargo" @("build", "--release")

    $Exe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    if (-not (Test-Path $Exe)) {
        Fail "Release executable was not produced."
    }

    Write-Host ""
    Write-Host "[2/5] Verifying the Batsu-resolved development codebook..."
    $CodebookAudit = Join-Path $WorkRoot "batsu-codebook-audit.json"
    Run-Native $Exe @(
        "audit-dialogue-codebook",
        "--cue", $TargetCue,
        "--codebook", $Codebook,
        "--output", $CodebookAudit
    )

    $CodebookAuditObj = (Read-Utf8Text $CodebookAudit) | ConvertFrom-Json
    if ($CodebookAuditObj.verified_entry_count -ne 1683) {
        Fail ("Expected 1683 verified source glyph identities; got {0}" -f $CodebookAuditObj.verified_entry_count)
    }
    if ($CodebookAuditObj.unresolved_used_source_pixel_hash_count -ne 0) {
        Fail "The Batsu development codebook still contains unresolved source hashes."
    }

    Write-Host ""
    Write-Host "[3/5] Initializing the resolved-primary translation workspace..."
    Run-Native $Exe @(
        "init-dialogue-translation",
        "--cue", $TargetCue,
        "--codebook", $Codebook,
        "--output", $Workspace,
        "--scope", "resolved-primary",
        "--force"
    )
}
finally {
    Pop-Location
}

# Load the 210 translated Batsu coordinates and index English segments by coordinate ID.
$route = (Read-Utf8Text $RouteTranslation) | ConvertFrom-Json
$englishByCoordinate = @{}
foreach ($entry in $route.entries) {
    $coordinate = [string]$entry.coordinate_id
    if ($englishByCoordinate.ContainsKey($coordinate)) {
        Fail ("Duplicate Batsu route coordinate in package: {0}" -f $coordinate)
    }
    $englishByCoordinate[$coordinate] = @($entry.english_segments_draft)
}

# Discover current semantic groups from immutable CONTEXT shards by coordinate.
#
# Upstream source shards intentionally do not retain the coordinate-ID lists.
# Exact coordinate membership lives in route context shards, which bind
# coordinate_id -> semantic_source_sha256.
$englishBySemantic = @{}
$coordinatesFound = New-Object System.Collections.Generic.HashSet[string]
$contextShardCount = 0
$matchingContextOccurrenceCount = 0

$workspaceJsonFiles = @(Get-ChildItem $Workspace -Recurse -Filter *.json -File)
foreach ($file in $workspaceJsonFiles) {
    $obj = $null
    try {
        $obj = (Read-Utf8Text $file.FullName) | ConvertFrom-Json
    }
    catch {
        continue
    }

    if ($null -eq $obj.entries) {
        continue
    }

    $isContextShard = (
        [string]$obj.kind -eq "Justice Gakuen 2 route dialogue context shard"
    )

    if (-not $isContextShard) {
        foreach ($candidate in @($obj.entries)) {
            if ($null -ne $candidate.PSObject.Properties["coordinate_id"] -and
                $null -ne $candidate.PSObject.Properties["semantic_source_sha256"] -and
                $null -ne $candidate.PSObject.Properties["occurrence_id"]) {
                $isContextShard = $true
                break
            }
        }
    }

    if (-not $isContextShard) {
        continue
    }

    $contextShardCount += 1

    foreach ($contextEntry in @($obj.entries)) {
        $coordinate = [string]$contextEntry.coordinate_id
        if (-not $englishByCoordinate.ContainsKey($coordinate)) {
            continue
        }

        $semantic = [string]$contextEntry.semantic_source_sha256
        if ([string]::IsNullOrWhiteSpace($semantic)) {
            Fail ("Context entry for {0} has no semantic_source_sha256." -f $coordinate)
        }

        $matchingContextOccurrenceCount += 1
        [void]$coordinatesFound.Add($coordinate)

        $segments = @($englishByCoordinate[$coordinate])
        $segmentsJson = ($segments | ConvertTo-Json -Compress)

        if ($englishBySemantic.ContainsKey($semantic)) {
            $existingJson = (@($englishBySemantic[$semantic]) | ConvertTo-Json -Compress)
            if ($existingJson -ne $segmentsJson) {
                Fail (
                    "Batsu coordinates sharing current semantic group {0} have conflicting English drafts." -f
                    $semantic
                )
            }
        }
        else {
            $englishBySemantic[$semantic] = $segments
        }
    }
}

if ($contextShardCount -eq 0) {
    Fail "No route context shards were discovered in the initialized workspace."
}
if ($englishBySemantic.Count -eq 0) {
    Fail "No Batsu coordinates matched the initialized resolved-primary context shards."
}

$unmatchedCoordinates = @(
    $englishByCoordinate.Keys |
        Where-Object { -not $coordinatesFound.Contains([string]$_) } |
        Sort-Object
)

Write-Host ("  Route context shards discovered: {0}" -f $contextShardCount)
Write-Host ("  Batsu package coordinates: {0}" -f $englishByCoordinate.Count)
Write-Host ("  Referenced Batsu coordinates found: {0}" -f $coordinatesFound.Count)
Write-Host ("  Matching route-context occurrences: {0}" -f $matchingContextOccurrenceCount)
Write-Host ("  Current semantic groups to author: {0}" -f $englishBySemantic.Count)
Write-Host ("  Package coordinates not directly referenced by primary routes: {0}" -f $unmatchedCoordinates.Count)

# Author the corresponding editable translation decisions.
$updatedGroups = 0
$updatedShardCount = 0
$updatedSemantics = New-Object System.Collections.Generic.HashSet[string]

foreach ($file in $workspaceJsonFiles) {
    $obj = $null
    try {
        $obj = (Read-Utf8Text $file.FullName) | ConvertFrom-Json
    }
    catch {
        continue
    }

    if ($null -eq $obj.entries) {
        continue
    }

    $isTranslationShard = $false
    foreach ($candidate in @($obj.entries)) {
        if ($null -ne $candidate.PSObject.Properties["korean_segments"] -and
            $null -ne $candidate.PSObject.Properties["status"]) {
            $isTranslationShard = $true
            break
        }
    }
    if (-not $isTranslationShard) {
        continue
    }

    $changed = $false
    foreach ($decision in @($obj.entries)) {
        $semantic = [string]$decision.semantic_source_sha256
        if (-not $englishBySemantic.ContainsKey($semantic)) {
            continue
        }

        $segments = @($englishBySemantic[$semantic])
        if (@($decision.korean_segments).Count -ne $segments.Count) {
            Fail (
                "Segment count changed for semantic group {0}: workspace={1}, English={2}" -f
                $semantic, @($decision.korean_segments).Count, $segments.Count
            )
        }

        # Upstream schema calls this korean_segments; for our fork the field is
        # temporarily used as the generic authored target-language segment array.
        $decision.korean_segments = @($segments)
        $decision.status = "draft"
        $decision.translator = "Justice Gakuen English Project"
        $decision.notes = "English draft v1 imported from MGT00/Batsu package; upstream field name korean_segments retained pending English schema rename."

        [void]$updatedSemantics.Add($semantic)
        $updatedGroups += 1
        $changed = $true
    }

    if ($changed) {
        $json = $obj | ConvertTo-Json -Depth 100
        Write-Utf8NoBom $file.FullName ($json + [Environment]::NewLine)
        $updatedShardCount += 1
    }
}

if ($updatedGroups -ne $englishBySemantic.Count) {
    Fail (
        "Only {0} of {1} current Batsu semantic groups were found in editable translation shards." -f
        $updatedGroups, $englishBySemantic.Count
    )
}

Write-Host ("  Authored semantic groups: {0}" -f $updatedGroups)
Write-Host ("  Translation shards changed: {0}" -f $updatedShardCount)

# Audit the edited workspace against original media and the corrected codebook.
Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[4/5] Auditing the Batsu-authored workspace..."
    $Exe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    Run-Native $Exe @(
        "audit-dialogue-translation",
        "--cue", $TargetCue,
        "--codebook", $Codebook,
        "--translation", $Workspace,
        "--output", $Audit
    )
}
finally {
    Pop-Location
}

$auditObj = (Read-Utf8Text $Audit) | ConvertFrom-Json
if ($auditObj.draft_group_count -lt $updatedGroups) {
    Fail (
        "Translation audit reports only {0} draft groups after importing {1} Batsu groups." -f
        $auditObj.draft_group_count, $updatedGroups
    )
}

$report = [ordered]@{
    kind = "Justice Gakuen 2 English Project - Batsu workspace bootstrap report"
    source_bin_sha256 = $SourceHash
    batsu_package = (Split-Path $BatsuPackage -Leaf)
    package_coordinate_count = $englishByCoordinate.Count
    referenced_package_coordinates_found = $coordinatesFound.Count
    matching_route_context_occurrence_count = $matchingContextOccurrenceCount
    unreferenced_package_coordinate_count = $unmatchedCoordinates.Count
    authored_current_semantic_group_count = $updatedGroups
    translation_shards_changed = $updatedShardCount
    workspace_semantic_group_count = $auditObj.semantic_group_count
    workspace_untranslated_group_count = $auditObj.untranslated_group_count
    workspace_draft_group_count = $auditObj.draft_group_count
    workspace_ready_for_font_repertoire = $auditObj.ready_for_font_repertoire
    development_translation_input_available = $auditObj.development_translation_input_available
    note = "Incomplete workspace is expected. This bootstrap validates Batsu English against current source/control bindings before authored-subset insertion."
}
Write-Utf8NoBom $ImportReport (($report | ConvertTo-Json -Depth 20) + [Environment]::NewLine)

Write-Host ""
Write-Host "Workspace audit:" -ForegroundColor Cyan
Write-Host ("  Semantic groups total: {0}" -f $auditObj.semantic_group_count)
Write-Host ("  Untranslated groups: {0}" -f $auditObj.untranslated_group_count)
Write-Host ("  Draft groups: {0}" -f $auditObj.draft_group_count)
Write-Host ("  Ready for full font repertoire: {0}" -f $auditObj.ready_for_font_repertoire)
Write-Host ""
Write-Host "The false readiness values are EXPECTED for a Batsu-only authored subset."

# Package the complete bootstrapped workspace for the next insertion step.
$PackageOut = Join-Path $WorkRoot "upload-package"
New-Item -ItemType Directory -Force -Path $PackageOut | Out-Null
Copy-Item $Workspace (Join-Path $PackageOut "translation-workspace") -Recurse
Copy-Item $Codebook (Join-Path $PackageOut "batsu-codebook.json")
Copy-Item $Audit (Join-Path $PackageOut "translation-audit.json")
Copy-Item $ImportReport (Join-Path $PackageOut "batsu-import-report.json")
Copy-Item $RouteTranslation (Join-Path $PackageOut "justice_gakuen_batsu_route_translation_v1.json")

if (Test-Path $OutputZip) {
    Remove-Item $OutputZip -Force
}

Write-Host ""
Write-Host "[5/5] Packaging the Batsu-native translation workspace..."
Compress-Archive -Path (Join-Path $PackageOut "*") -DestinationPath $OutputZip -CompressionLevel Optimal

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "BATSU ENGLISH WORKSPACE BOOTSTRAP V4 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload this ZIP back to ChatGPT:" -ForegroundColor Yellow
Write-Host $OutputZip -ForegroundColor Yellow

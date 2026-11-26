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

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$InputCodebook = Join-Path $Here "justice_gakuen_english_codebook_stage2_corrected.json"
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder." }
if (-not (Test-Path $InputCodebook)) {
    Fail "Put justice_gakuen_english_codebook_stage2_corrected.json beside this script."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { Fail "Cargo is not on PATH." }

$bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
if ($bins.Count -ne 1) {
    Fail "Expected exactly one .bin in $RomFolder; found $($bins.Count)."
}
$SourceBin = $bins[0].FullName
$SourceHash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
Write-Host "Source BIN SHA-256: $SourceHash"
if ($SourceHash -ne $ExpectedBinHash) { Fail "This is not the exact BIN we audited." }

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

# Preserve/install the Windows 64 MB stack wrapper.
$MainRs = Join-Path $Upstream "src\main.rs"
$mainText = [System.IO.File]::ReadAllText($MainRs)
$StackMarker = "justice-gakuen2-large-stack"
if (-not $mainText.Contains($StackMarker)) {
    $old = "fn main() -> Result<()> {"
    $count = ([regex]::Matches($mainText, [regex]::Escape($old))).Count
    if ($count -ne 1) { Fail "Could not safely patch Rust main() for a larger stack." }
    $mainText = $mainText.Replace($old, "fn app_main() -> Result<()> {")
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
        $MainRs, $mainText + $wrapper, (New-Object System.Text.UTF8Encoding($false))
    )
}

# Preserve/install the larger review JSON shard ceiling.
$ReviewRs = Join-Path $Upstream "src\dialogue_audit\review.rs"
$reviewText = [System.IO.File]::ReadAllText($ReviewRs)
$small = "const MAXIMUM_REVIEW_SHARD_BYTES: usize = 512 * 1024;"
$large = "const MAXIMUM_REVIEW_SHARD_BYTES: usize = 16 * 1024 * 1024;"
if ($reviewText.Contains($small)) {
    $reviewText = $reviewText.Replace($small, $large)
    [System.IO.File]::WriteAllText(
        $ReviewRs, $reviewText, (New-Object System.Text.UTF8Encoding($false))
    )
}

$Work = Join-Path $Upstream "work"
$CodebookDir = Join-Path $Work "english-dialogue-codebook"
$Codebook = Join-Path $CodebookDir "codebook.json"
$Audit = Join-Path $Work "english-dialogue-codebook-stage2-corrected-audit.json"
$ReviewDir = Join-Path $Work "english-dialogue-codebook-review-stage3"
$PackageDir = Join-Path $Work "english-dialogue-codebook-stage3-package"
$Zip = Join-Path $Work "english-dialogue-codebook-review-stage3.zip"

New-Item -ItemType Directory -Force -Path $CodebookDir | Out-Null
Copy-Item $InputCodebook $Codebook -Force

$cbText = [System.IO.File]::ReadAllText($Codebook)
[System.IO.File]::WriteAllText(
    $Codebook, $cbText, (New-Object System.Text.UTF8Encoding($false))
)

if (Test-Path $ReviewDir) { Remove-Item $ReviewDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $ReviewDir | Out-Null

Write-Host ""
Write-Host "Justice Gakuen English Project - Corrected Codebook Stage 3" -ForegroundColor Cyan

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/4] Building..."
    Run-Native "cargo" @("build", "--release")
    $Exe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    if (-not (Test-Path $Exe)) { Fail "Release executable was not produced." }

    Write-Host ""
    Write-Host "[2/4] Auditing corrected 384-entry Japanese codebook..."
    Run-Native $Exe @(
        "audit-dialogue-codebook",
        "--cue", $TargetCue,
        "--codebook", $Codebook,
        "--output", $Audit
    )

    $AuditObj = Get-Content $Audit -Raw | ConvertFrom-Json
    Write-Host "  Verified entries: $($AuditObj.verified_entry_count)"
    Write-Host "  Resolved used glyph hashes: $($AuditObj.resolved_used_source_pixel_hash_count)"
    Write-Host "  Remaining unresolved hashes: $($AuditObj.unresolved_used_source_pixel_hash_count)"
    Write-Host "  Remaining unresolved occurrences: $($AuditObj.unresolved_glyph_occurrence_count)"

    if ($AuditObj.verified_entry_count -ne 384) {
        Fail "Expected 384 verified entries; got $($AuditObj.verified_entry_count)."
    }
    if ($AuditObj.unresolved_used_source_pixel_hash_count -ne 1299) {
        Fail "Expected 1299 unresolved hashes; got $($AuditObj.unresolved_used_source_pixel_hash_count)."
    }
    if ($AuditObj.unresolved_glyph_occurrence_count -ne 75223) {
        Fail "Expected 75223 unresolved occurrences; got $($AuditObj.unresolved_glyph_occurrence_count)."
    }

    Write-Host ""
    Write-Host "[3/4] Rebuilding review pages with corrected common glyphs..."
    Run-Native $Exe @(
        "preview-dialogue-codebook-review",
        "--cue", $TargetCue,
        "--codebook", $Codebook,
        "--output-dir", $ReviewDir
    )
}
finally {
    Pop-Location
}

$Manifest = Join-Path $ReviewDir "dialogue-codebook-review.json"
if (-not (Test-Path $Manifest)) { Fail "Stage-3 review manifest was not produced." }
$ReviewObj = Get-Content $Manifest -Raw | ConvertFrom-Json

Write-Host ""
Write-Host "Stage-3 review:" -ForegroundColor Cyan
Write-Host "  Remaining glyph hashes: $($ReviewObj.unresolved_used_source_pixel_hash_count)"
Write-Host "  Remaining occurrences: $($ReviewObj.unresolved_glyph_occurrence_count)"
Write-Host "  Review pages: $($ReviewObj.pages.Count)"

if (Test-Path $PackageDir) { Remove-Item $PackageDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
Copy-Item $Codebook (Join-Path $PackageDir "codebook.json")
Copy-Item $Audit (Join-Path $PackageDir "audit.json")
Copy-Item $ReviewDir (Join-Path $PackageDir "review") -Recurse
if (Test-Path $Zip) { Remove-Item $Zip -Force }

Write-Host ""
Write-Host "[4/4] Packaging Stage-3 review..."
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Zip -CompressionLevel Optimal

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "CORRECTED DIALOGUE CODEBOOK STAGE 3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload this ZIP back to ChatGPT:" -ForegroundColor Yellow
Write-Host $Zip -ForegroundColor Yellow

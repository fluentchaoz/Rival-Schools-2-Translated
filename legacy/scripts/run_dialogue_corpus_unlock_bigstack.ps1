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
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not available on PATH."
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
$TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

New-Item -ItemType Directory -Force -Path $Roms | Out-Null
if (-not (Test-Path $TargetBin) -or
    (Get-FileHash -Algorithm SHA256 $TargetBin).Hash.ToLower() -ne $ExpectedBinHash) {
    Copy-Item $SourceBin $TargetBin -Force
}

@'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $TargetCue

$Work = Join-Path $Upstream "work"
$CodebookDir = Join-Path $Work "english-dialogue-codebook"
$Codebook = Join-Path $CodebookDir "codebook.json"
$ReviewDir = Join-Path $Work "english-dialogue-codebook-review"
$PackageDir = Join-Path $Work "english-dialogue-codebook-package"
$Zip = Join-Path $Work "english-dialogue-codebook-review.zip"

New-Item -ItemType Directory -Force -Path $CodebookDir | Out-Null

if (-not (Test-Path $Codebook)) {
    $CodebookObject = [ordered]@{
        kind = "Justice Gakuen 2 asset-scoped dialogue glyph codebook"
        source_bin_sha256 = $ExpectedBinHash
        evidence_sources = [ordered]@{
            english_project_manual_review = "Human review of source glyph cells and source-bound dialogue contexts from the original Japanese disc"
        }
        entries = @()
    }
    $CodebookObject | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $Codebook
}

$MainRs = Join-Path $Upstream "src\main.rs"
if (-not (Test-Path $MainRs)) {
    Fail "Missing src\main.rs"
}

$Marker = "justice-gakuen2-large-stack"
$mainText = [System.IO.File]::ReadAllText($MainRs)

if (-not $mainText.Contains($Marker)) {
    $old = "fn main() -> Result<()> {"
    $count = ([regex]::Matches($mainText, [regex]::Escape($old))).Count
    if ($count -ne 1) {
        Fail "Expected exactly one Rust main() function, found $count."
    }

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
        $MainRs,
        $mainText + $wrapper,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Patched CLI to use a 64 MB worker-thread stack." -ForegroundColor Cyan
}
else {
    Write-Host "64 MB stack wrapper already installed." -ForegroundColor Cyan
}

if (Test-Path $ReviewDir) {
    Remove-Item $ReviewDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ReviewDir | Out-Null

Write-Host ""
Write-Host "Justice Gakuen English Project - Dialogue Corpus Unlock (large-stack recovery)" -ForegroundColor Cyan

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/3] Rebuilding CLI with 64 MB stack wrapper..."
    Run-Native "cargo" @("build", "--release")

    $Exe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    if (-not (Test-Path $Exe)) {
        Fail "Release executable was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Inventorying every dialogue glyph used by the game..."
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
if (-not (Test-Path $Manifest)) {
    Fail "Dialogue review manifest was not produced."
}

$Review = Get-Content $Manifest -Raw | ConvertFrom-Json
Write-Host ""
Write-Host "Inventory results:" -ForegroundColor Cyan
Write-Host "  Unresolved used glyph hashes: $($Review.unresolved_used_source_pixel_hash_count)"
Write-Host "  Total unresolved glyph occurrences: $($Review.unresolved_glyph_occurrence_count)"
Write-Host "  Review pages: $($Review.pages.Count)"
Write-Host "  Glyph cell: $($Review.cell_width)x$($Review.cell_height)"
Write-Host "  Slots per page: $($Review.slots_per_page)"

if (Test-Path $PackageDir) {
    Remove-Item $PackageDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PackageDir | Out-Null
Copy-Item $Codebook (Join-Path $PackageDir "codebook.json")
Copy-Item $ReviewDir (Join-Path $PackageDir "review") -Recurse

if (Test-Path $Zip) {
    Remove-Item $Zip -Force
}

Write-Host ""
Write-Host "[3/3] Packaging review pages and context JSON..."
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Zip -CompressionLevel Optimal

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "DIALOGUE GLYPH INVENTORY COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload this ZIP back to ChatGPT:" -ForegroundColor Yellow
Write-Host $Zip -ForegroundColor Yellow

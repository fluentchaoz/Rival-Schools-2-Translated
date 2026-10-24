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
    Fail "Missing upstream folder. Run the earlier Phase 1 / Gate scripts first."
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

if (-not (Test-Path $TargetBin) -or
    (Get-FileHash -Algorithm SHA256 $TargetBin).Hash.ToLower() -ne $ExpectedBinHash) {
    New-Item -ItemType Directory -Force -Path $Roms | Out-Null
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

$CodebookObject = [ordered]@{
    kind = "Justice Gakuen 2 asset-scoped dialogue glyph codebook"
    source_bin_sha256 = $ExpectedBinHash
    evidence_sources = [ordered]@{
        english_project_manual_review = "Human review of source glyph cells and source-bound dialogue contexts from the original Japanese disc"
    }
    entries = @()
}
$CodebookObject | ConvertTo-Json -Depth 10 | Set-Content -Encoding UTF8 $Codebook

if (Test-Path $ReviewDir) {
    Remove-Item $ReviewDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ReviewDir | Out-Null

Write-Host ""
Write-Host "Justice Gakuen English Project - Dialogue Corpus Unlock" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1/4] Building the public extraction/review tool..."
Push-Location $Upstream
try {
    Run-Native "cargo" @("build", "--release")

    Write-Host ""
    Write-Host "[2/4] Inventorying every dialogue glyph used by the game..."
    Run-Native "cargo" @(
        "run", "--release", "--",
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
Write-Host "[3/4] Review inventory:"
Write-Host "Unresolved used glyph hashes: $($Review.unresolved_used_source_pixel_hash_count)"
Write-Host "Total unresolved glyph occurrences: $($Review.unresolved_glyph_occurrence_count)"
Write-Host "Review pages: $($Review.pages.Count)"
Write-Host "Glyph cell: $($Review.cell_width)x$($Review.cell_height)"
Write-Host "Slots per page: $($Review.slots_per_page)"

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
Write-Host "[4/4] Packaging review pages and context JSON..."
Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $Zip -CompressionLevel Optimal

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "DIALOGUE GLYPH INVENTORY COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Upload this ZIP back to ChatGPT:"
Write-Host $Zip -ForegroundColor Yellow
Write-Host ""
Write-Host "This ZIP contains the glyph contact sheets and source contexts needed"
Write-Host "to reconstruct the Japanese dialogue codebook."

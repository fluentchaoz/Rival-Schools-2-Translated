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

$Work = Join-Path $Upstream "work"
$Codebook = Join-Path $Work "english-dialogue-codebook\codebook.json"
$ReviewDir = Join-Path $Work "english-dialogue-codebook-review"
$PackageDir = Join-Path $Work "english-dialogue-codebook-package"
$Zip = Join-Path $Work "english-dialogue-codebook-review.zip"

if (-not (Test-Path $Codebook)) {
    Fail "Missing $Codebook"
}

# Always normalize JSON to UTF-8 without BOM.
$codebookText = [System.IO.File]::ReadAllText($Codebook)
[System.IO.File]::WriteAllText(
    $Codebook,
    $codebookText,
    (New-Object System.Text.UTF8Encoding($false))
)

$ReviewRs = Join-Path $Upstream "src\dialogue_audit\review.rs"
if (-not (Test-Path $ReviewRs)) {
    Fail "Missing src\dialogue_audit\review.rs"
}

$text = [System.IO.File]::ReadAllText($ReviewRs)

$old = "const MAXIMUM_REVIEW_SHARD_BYTES: usize = 512 * 1024;"
$new = "const MAXIMUM_REVIEW_SHARD_BYTES: usize = 16 * 1024 * 1024;"

if ($text.Contains($old)) {
    $text = $text.Replace($old, $new)
    [System.IO.File]::WriteAllText(
        $ReviewRs,
        $text,
        (New-Object System.Text.UTF8Encoding($false))
    )
    Write-Host "Raised review-shard ceiling from 512 KB to 16 MB." -ForegroundColor Cyan
}
elseif ($text.Contains($new)) {
    Write-Host "16 MB review-shard ceiling already installed." -ForegroundColor Cyan
}
else {
    Fail "Could not find the expected review shard-size constant."
}

if (Test-Path $ReviewDir) {
    Remove-Item $ReviewDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ReviewDir | Out-Null

Write-Host ""
Write-Host "Justice Gakuen English Project - Dialogue Corpus Unlock (v2)" -ForegroundColor Cyan

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/3] Rebuilding review tool with larger shard ceiling..."
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

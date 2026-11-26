param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder
)

$ErrorActionPreference = "Stop"

function Fail($msg) {
    Write-Host ""
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = $Here
$Upstream = Join-Path $ProjectRoot "upstream"
$Patch = Join-Path $ProjectRoot "upstream_source_variant.patch"

Write-Host "Justice Gakuen English Project - Phase 1 local bootstrap" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Patch)) {
    Fail "upstream_source_variant.patch is missing from $ProjectRoot"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Fail "Git is not installed or not on PATH. Install Git for Windows, reopen PowerShell, and rerun this script."
}

$rustup = Get-Command rustup -ErrorAction SilentlyContinue
if (-not $rustup) {
    Fail "rustup is not installed or not on PATH. Install Rust via rustup, reopen PowerShell, and rerun this script."
}

$cargo = Get-Command cargo -ErrorAction SilentlyContinue
if (-not $cargo) {
    Fail "Cargo is not available on PATH after rustup installation."
}

if (-not (Test-Path $RomFolder)) {
    Fail "ROM folder does not exist: $RomFolder"
}

$bins = Get-ChildItem -Path $RomFolder -Filter *.bin -File
$cues = Get-ChildItem -Path $RomFolder -Filter *.cue -File

if ($bins.Count -ne 1) {
    Fail "Expected exactly one .bin in $RomFolder, found $($bins.Count)."
}
if ($cues.Count -ne 1) {
    Fail "Expected exactly one .cue in $RomFolder, found $($cues.Count)."
}

$SourceBin = $bins[0].FullName
$SourceCue = $cues[0].FullName

$hash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
$expected = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

Write-Host "Source BIN: $SourceBin"
Write-Host "SHA-256:    $hash"

if ($hash -ne $expected) {
    Fail "This is not the exact BIN we audited. Expected $expected"
}

Write-Host ""
Write-Host "[1/6] Installing/selecting Rust 1.98.0..."
rustup toolchain install 1.98.0 --profile minimal --component clippy --component rustfmt
rustup override set 1.98.0

Write-Host ""
Write-Host "[2/6] Getting upstream source..."
if (-not (Test-Path $Upstream)) {
    git clone https://github.com/mcpads/justice-gakuen2-kr-patch.git $Upstream
} else {
    Write-Host "Using existing upstream folder: $Upstream"
}

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[3/6] Resetting upstream checkout and applying our audited source-variant patch..."
    git reset --hard
    git clean -fd

    git apply --check $Patch
    git apply $Patch

    Write-Host ""
    Write-Host "[4/6] Preparing ROM path expected by the toolchain..."
    $Roms = Join-Path $Upstream "roms"
    New-Item -ItemType Directory -Force -Path $Roms | Out-Null

    $TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
    $TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"

    Copy-Item $SourceBin $TargetBin -Force

    @'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $TargetCue

    Write-Host ""
    Write-Host "[5/6] Building release toolchain..."
    cargo build --release

    Write-Host ""
    Write-Host "[6/6] Running public/synthetic tests..."
    cargo test

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "PHASE 1 LOCAL BUILD PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Do NOT run the ignored/private-asset tests yet."
    Write-Host "Send me the final PowerShell output from this script."
}
finally {
    Pop-Location
}

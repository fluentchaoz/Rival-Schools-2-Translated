param()

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

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$ProbePath = Join-Path $Upstream "src\source_disc.rs"
$InputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.bin"
$ExpectedInputHash = "a8f2c7d4ebc025376a36ba84930dee75e6044632e04677ba1eff8cf6d70f0564"

if (-not (Test-Path $ProbePath)) {
    Fail "Missing upstream\src\source_disc.rs."
}
if (-not (Test-Path $InputBin)) {
    Fail "Missing the successful English Mode Select BIN."
}

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Input BIN is not the exact successful English Mode Select build."
}

$Text = [System.IO.File]::ReadAllText($ProbePath)

if (-not $Text.Contains("fn english_quick_school_life_title_menu_patch()")) {
    Fail "The School Life title-menu test module is not present."
}

# Replace only the target-label selection block inside the already source-bound
# School Life title-menu test. Six contextual MGTIT glyph cells are available;
# PLAY + LOAD uses exactly six unique characters: P,L,A,Y,O,D.
$Pattern = '(?s)let mut first_target = "NEW GAME"\.to_string\(\);.*?let continue_size = safe_owned_size\(\s*&source_overlay_decoded,\s*&all_offsets,\s*&cont,\s*&continue_target,\s*\)\?;'

$Regex = New-Object System.Text.RegularExpressions.Regex(
    $Pattern,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

$Matches = $Regex.Matches($Text)
if ($Matches.Count -ne 1) {
    # Allow rerunning after a partially repaired source only if PLAY/LOAD is
    # already present exactly once.
    if ($Text.Contains('let first_target = "PLAY".to_string();') -and
        $Text.Contains('let continue_target = "LOAD".to_string();')) {
        Write-Host "PLAY / LOAD target block already installed." -ForegroundColor Cyan
    }
    else {
        Fail ("Expected exactly one NEW GAME/CONTINUE target block, found {0}." -f $Matches.Count)
    }
}
else {
$Replacement = @'
let first_target = "PLAY".to_string();
        let first_size = safe_owned_size(
            &source_overlay_decoded,
            &all_offsets,
            &new_game,
            &first_target,
        )?;
        let continue_target = "LOAD".to_string();
        let continue_size = safe_owned_size(
            &source_overlay_decoded,
            &all_offsets,
            &cont,
            &continue_target,
        )?;
'@
    $Text = $Regex.Replace($Text, $Replacement, 1)

    [System.IO.File]::WriteAllText(
        $ProbePath,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

# Verify we are not about to ask the six-cell allocator for too many unique
# characters again.
$TargetChars = ("PLAYLOAD".ToCharArray() | Sort-Object -Unique)
Write-Host ""
Write-Host "Justice Gakuen English Project - School Life Start Menu v3" -ForegroundColor Cyan
Write-Host ("MGTIT contextual glyph capacity: 6")
Write-Host ("PLAY / LOAD unique glyph demand: {0} ({1})" -f $TargetChars.Count, ($TargetChars -join ","))
if ($TargetChars.Count -gt 6) {
    Fail "PLAY / LOAD unexpectedly exceeds the six-slot MGTIT glyph budget."
}

Write-Host ""
Write-Host "[1/3] Building source-bound PLAY / LOAD patch..."

Push-Location $Upstream
try {
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_quick_school_life_title_menu::english_quick_school_life_title_menu_patch",
        "--", "--exact", "--nocapture"
    )

    $OutputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus-title.bin"
    if (-not (Test-Path $OutputBin)) {
        Fail "School Life title-menu test passed but no output BIN was produced."
    }

    Write-Host ""
    Write-Host "[2/3] Writing matching CUE..."
    $OutputCue = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus-title.cue"
    @'
FILE "justice-gakuen2-batsu-english-scene1-menus-title.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $OutputCue

    Write-Host ""
    Write-Host "[3/3] Hashing final build..."
    $OutputHash = (Get-FileHash -Algorithm SHA256 $OutputBin).Hash.ToLower()
    Write-Host ("Output SHA-256: {0}" -f $OutputHash)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "SCHOOL LIFE START MENU V3 COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected screen:" -ForegroundColor Cyan
    Write-Host "  PLAY"
    Write-Host "  LOAD"
}
finally {
    Pop-Location
}

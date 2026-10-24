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
$InputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1.bin"
$ExpectedV7Hash = "d9b1a57313e3714980f4c618aeffb975bb00286bdcdcab1a4a9a0fb24ab850f2"

if (-not (Test-Path $ProbePath)) {
    Fail "Missing upstream\src\source_disc.rs."
}
if (-not (Test-Path $InputBin)) {
    Fail "Missing successful v7 Batsu prototype BIN."
}

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedV7Hash) {
    Fail "Input BIN is not the exact successful v7 Batsu prototype."
}

$Text = [System.IO.File]::ReadAllText($ProbePath)

if (-not $Text.Contains("fn english_quick_mode_select_menu_patch()")) {
    Fail "The quick-menu Rust test module is not present. Run the original quick-menu script once first."
}

$Before = $Text

# IMPORTANT: construct the old strings in pieces so this PowerShell source cannot
# accidentally self-rewrite them while a later script version is generated.
$OldStartX = 'let start_x = ' + '(width - text_width) / 2;'
$NewStartX = 'let start_x = width.saturating_sub(text_width) / 2;'
$OldStartY = 'let start_y = ' + '(height - text_height) / 2;'
$NewStartY = 'let start_y = height.saturating_sub(text_height) / 2;'

$OldCreate = '("CREATE A STUDENT", 39usize, ' + '2usize)'
$NewCreate = '("CREATE A STUDENT", 39usize, 1usize)'

$OldFriends = '("MAKE FRIENDS ' + '& TRAIN", 82usize, 1usize)'
$NewFriends = '("MAKE FRIENDS AND TRAIN", 82usize, 1usize)'

$StartXCount = ([regex]::Matches($Text, [regex]::Escape($OldStartX))).Count
$StartYCount = ([regex]::Matches($Text, [regex]::Escape($OldStartY))).Count
$CreateCount = ([regex]::Matches($Text, [regex]::Escape($OldCreate))).Count
$FriendsCount = ([regex]::Matches($Text, [regex]::Escape($OldFriends))).Count

$Text = $Text.Replace($OldStartX, $NewStartX)
$Text = $Text.Replace($OldStartY, $NewStartY)
$Text = $Text.Replace($OldCreate, $NewCreate)
$Text = $Text.Replace($OldFriends, $NewFriends)

if ($Text.Contains($OldStartX) -or $Text.Contains($OldStartY)) {
    Fail "Unsigned menu-centering subtraction still exists after repair."
}
if ($Text.Contains($OldCreate)) {
    Fail "Oversized CREATE A STUDENT line still exists after repair."
}
if ($Text.Contains($OldFriends)) {
    Fail "Unsupported ampersand line still exists after repair."
}

if ($Text -ne $Before) {
    [System.IO.File]::WriteAllText(
        $ProbePath,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

Write-Host ""
Write-Host "Justice Gakuen English Project - Quick Mode Select Repair v4" -ForegroundColor Cyan
Write-Host ("  Replaced unsafe X-centering expressions: {0}" -f $StartXCount)
Write-Host ("  Replaced unsafe Y-centering expressions: {0}" -f $StartYCount)
Write-Host ("  Repaired oversized description lines: {0}" -f $CreateCount)
Write-Host ("  Repaired unsupported ampersands: {0}" -f $FriendsCount)

# Print the exact live source around the old panic line so we KNOW what Cargo sees.
$Lines = [System.IO.File]::ReadAllLines($ProbePath)
Write-Host ""
Write-Host "Live Rust source around line 967:" -ForegroundColor Yellow
for ($LineNo = 963; $LineNo -le 971; $LineNo++) {
    if ($LineNo -le $Lines.Length) {
        Write-Host ("  {0}: {1}" -f $LineNo, $Lines[$LineNo - 1])
    }
}

if ($Lines.Length -ge 967 -and $Lines[966].Contains("width - text_width")) {
    Fail "Line 967 is STILL the unsafe subtraction. Refusing to compile."
}

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "[1/3] Running repaired MODE SELECT translation..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_quick_mode_select_menu::english_quick_mode_select_menu_patch",
        "--", "--exact", "--nocapture"
    )

    $OutputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.bin"
    if (-not (Test-Path $OutputBin)) {
        Fail "Menu test passed but output BIN was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Writing matching CUE..."
    $OutputCue = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.cue"
    @'
FILE "justice-gakuen2-batsu-english-scene1-menus.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $OutputCue

    Write-Host ""
    Write-Host "[3/3] Hashing final menu-test build..."
    $OutputHash = (Get-FileHash -Algorithm SHA256 $OutputBin).Hash.ToLower()
    Write-Host ("Output SHA-256: {0}" -f $OutputHash)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "QUICK ENGLISH MODE SELECT V4 COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
}
finally {
    Pop-Location
}

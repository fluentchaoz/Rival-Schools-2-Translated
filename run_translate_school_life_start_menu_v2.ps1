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
    Fail "The School Life title-menu test module is not present. Run the first title-menu script once first."
}

# Replace the original heuristic finder with exact source-bound placement matching
# discovered from the user's own MGTIT placement table:
#   idx 0 = x60 y60, 4 glyphs  -> 入学する
#   idx 1 = x60 y90, 9 glyphs  -> つづきからはじめる
$OldPattern = '(?s)fn find_pair\(all: &\[Placement\]\) -> Result<\(Placement, Placement\)> \{.*?Ok\(pairs\.remove\(0\)\)\s*\}'
$Regex = New-Object System.Text.RegularExpressions.Regex(
    $OldPattern,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)

$Matches = $Regex.Matches($Text)
if ($Matches.Count -ne 1) {
    Fail ("Expected exactly one find_pair function to repair, found {0}." -f $Matches.Count)
}

$Replacement = @'
fn find_pair(all: &[Placement]) -> Result<(Placement, Placement)> {
        println!("MGTIT placement table:");
        for p in all {
            println!(
                "  idx={:02} placement=+0x{:04x} x={:4} y={:4} string=+0x{:04x} glyphs={} codes={:?}",
                p.index,
                p.record_offset,
                p.x,
                p.y,
                p.string_offset,
                p.codes.len(),
                p.codes
            );
        }

        let new_game = all
            .iter()
            .find(|p| {
                p.index == 0
                    && p.x == 60
                    && p.y == 60
                    && p.string_offset == 0x0010
                    && p.codes.len() == 4
            })
            .cloned()
            .context("source-bound NEW entry (idx 0/x60/y60/+0x0010/4 glyphs) not found")?;

        let cont = all
            .iter()
            .find(|p| {
                p.index == 1
                    && p.x == 60
                    && p.y == 90
                    && p.string_offset == 0x001c
                    && p.codes.len() == 9
            })
            .cloned()
            .context("source-bound CONTINUE entry (idx 1/x60/y90/+0x001c/9 glyphs) not found")?;

        ensure!(
            cont.record_offset == new_game.record_offset + PLACEMENT_RECORD_SIZE,
            "NEW/CONTINUE placement records are no longer adjacent"
        );

        Ok((new_game, cont))
    }
'@

$Text = $Regex.Replace($Text, $Replacement, 1)

[System.IO.File]::WriteAllText(
    $ProbePath,
    $Text,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "Justice Gakuen English Project - School Life Start Menu v2" -ForegroundColor Cyan
Write-Host "Locked exact source placements:" -ForegroundColor Yellow
Write-Host "  NEW      idx 0, x=60, y=60, string +0x0010"
Write-Host "  CONTINUE idx 1, x=60, y=90, string +0x001c"
Write-Host ""
Write-Host "[1/3] Building exact NEW / CONTINUE patch..."

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
    Write-Host "SCHOOL LIFE START MENU V2 COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected screen:" -ForegroundColor Cyan
    Write-Host "  NEW"
    Write-Host "  CONTINUE"
}
finally {
    Pop-Location
}

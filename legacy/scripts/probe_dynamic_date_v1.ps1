$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    Write-Host ""
    Write-Host ("ERROR: {0}" -f $Message) -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$SourcePath = Join-Path $Upstream "src\source_disc.rs"

$InputBin = Join-Path $Upstream "work\english-road-to-batsu-opening-school-gate-fit\build\justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
$ExpectedInputHash = "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1"

$OutputRoot = Join-Path $Upstream "work\english-road-to-batsu-dynamic-date-probe-v1"
$ReportPath = Join-Path $OutputRoot "dynamic-date-renderer-map-v1.txt"
$AssetReportPath = Join-Path $OutputRoot "calendar-asset-map-v1.txt"

Write-Host ""
Write-Host "Justice Gakuen English Project - Dynamic Date Probe v1" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream directory beside this script." }
if (-not (Test-Path $SourcePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $InputBin)) { Fail "Missing opening SCHOOL GATE fit BIN." }

$InputHash = (Get-FileHash $InputBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Current base BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Current base is not the exact a2e158... SCHOOL GATE fit build."
}
Write-Host "Base hash verified." -ForegroundColor Green

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

# --------------------------------------------------------------------------
# Read the upstream diary-header asset map. This is especially useful because
# the upstream project already has semantic IDs such as calendar-month-monday.
# --------------------------------------------------------------------------
$AssetsDir = Join-Path $Upstream "assets\diary\header"
$ManifestPath = Join-Path $AssetsDir "manifest.json"

$AssetLines = New-Object System.Collections.Generic.List[string]
$AssetLines.Add("Justice Gakuen 2 calendar asset map")
$AssetLines.Add("")

if (Test-Path $ManifestPath) {
    $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $CalendarEntries = @()

    foreach ($UnitRelative in @($Manifest.units)) {
        $UnitPath = Join-Path $AssetsDir ([string]$UnitRelative)
        if (-not (Test-Path $UnitPath)) {
            $AssetLines.Add("MISSING UNIT: $UnitPath")
            continue
        }

        $Unit = Get-Content $UnitPath -Raw | ConvertFrom-Json
        foreach ($Entry in @($Unit.entries)) {
            if ([string]$Entry.font_role -eq "calendar_text") {
                $CalendarEntries += $Entry
            }
        }
    }

    $CalendarEntries = @(
        $CalendarEntries |
        Sort-Object `
            @{ Expression = { [int]$_.cell.y } }, `
            @{ Expression = { [int]$_.cell.x } }, `
            @{ Expression = { [string]$_.id } }
    )

    $AssetLines.Add(("CalendarText entries found: {0}" -f $CalendarEntries.Count))
    $AssetLines.Add("")

    foreach ($Entry in $CalendarEntries) {
        $Cell = $Entry.cell
        $AssetLines.Add((
            "{0} | source={1} | translated={2} | cell=({3},{4} {5}x{6}) | source_sha={7}" -f
            [string]$Entry.id,
            [string]$Entry.source_text,
            [string]$Entry.korean_text,
            [int]$Cell.x,
            [int]$Cell.y,
            [int]$Cell.width,
            [int]$Cell.height,
            [string]$Entry.source_region_sha256
        ))
    }
}
else {
    $AssetLines.Add("assets\diary\header\manifest.json was not present in this checkout.")
    $AssetLines.Add("The MGAME renderer probe will still run.")
}

[System.IO.File]::WriteAllLines(
    $AssetReportPath,
    $AssetLines,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "=== UPSTREAM CALENDAR ASSET MAP ===" -ForegroundColor Yellow
Get-Content $AssetReportPath

# --------------------------------------------------------------------------
# Inject a temporary Rust unit test so we can use the project's source-bound
# ISO reader and R3000A decoder without compiling the broken experimental bins.
# --------------------------------------------------------------------------
$Marker = "// ENGLISH_PROJECT_DYNAMIC_DATE_PROBE_V1"
$OriginalSource = [System.IO.File]::ReadAllText($SourcePath)

if ($OriginalSource.Contains($Marker)) {
    Fail "A stale Dynamic Date Probe v1 injection is already present in source_disc.rs."
}

$Rust = @'

// ENGLISH_PROJECT_DYNAMIC_DATE_PROBE_V1
#[cfg(test)]
mod english_dynamic_date_probe_v1 {
    use std::fmt::Write as _;
    use std::fs;
    use std::path::Path;

    use anyhow::{Result, ensure};
    use psx_r3000a::decode;

    const INPUT_HASH: &str =
        "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1";
    const MGAME_BASE: u32 = 0x800a_2000;

    fn pair_cell(u: u8, v: u8) -> String {
        if v == 0 && u % 16 == 0 {
            format!("row0-cell-{}", usize::from(u) / 16)
        } else {
            format!("u={u} v={v}")
        }
    }

    #[test]
    fn english_dynamic_date_probe_v1() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-road-to-batsu-opening-school-gate-fit/build/justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
        );
        let output_root = root.join("work/english-road-to-batsu-dynamic-date-probe-v1");
        let output = output_root.join("dynamic-date-renderer-map-v1.txt");

        ensure!(input.is_file(), "current SCHOOL GATE fit BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "current SCHOOL GATE fit BIN hash changed"
        );
        fs::create_dir_all(&output_root)?;

        let (_, mgame) =
            crate::disc::rebuild::read_record(&input, "DAT1/MGAME.BIN")?;
        let (_, mgcock_stored) =
            crate::disc::rebuild::read_record(&input, "DAT2/MGCOCK.TIZ")?;
        let mgcock = crate::compression::decompress(&mgcock_stored, false)?;
        let tim = crate::tim::parse_4bpp_prefix(&mgcock)?;

        ensure!(
            tim.pixel_width() == 1024 && tim.image_height == 256,
            "unexpected MGCOCK geometry"
        );
        ensure!(mgame.len() > 0x131b8, "MGAME is smaller than date routine");

        let mut report = String::new();
        writeln!(&mut report, "Justice Gakuen 2 dynamic date renderer map v1").unwrap();
        writeln!(&mut report).unwrap();
        writeln!(
            &mut report,
            "INPUT_BIN_SHA256={}",
            crate::pipeline::sha256_file(&input)?
        )
        .unwrap();
        writeln!(
            &mut report,
            "MGAME_SHA256={}",
            crate::pipeline::sha256_bytes(&mgame)
        )
        .unwrap();
        writeln!(
            &mut report,
            "MGCOCK_STORED_SHA256={}",
            crate::pipeline::sha256_bytes(&mgcock_stored)
        )
        .unwrap();
        writeln!(
            &mut report,
            "MGCOCK_DECODED_SHA256={}",
            crate::pipeline::sha256_bytes(&mgcock)
        )
        .unwrap();
        writeln!(
            &mut report,
            "MGCOCK_GEOMETRY={}x{}",
            tim.pixel_width(),
            tim.image_height
        )
        .unwrap();

        // The renderer at +0x13008 first copies four fixed UV pairs.
        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== FOUR FIXED DATE UV PAIRS @ MGAME +0x01bd0 ===").unwrap();
        for index in 0..4usize {
            let off = 0x1bd0 + index * 2;
            let u = mgame[off];
            let v = mgame[off + 1];
            writeln!(
                &mut report,
                "fixed[{index}] +0x{off:05x}: u={u:3} v={v:3}  {}",
                pair_cell(u, v)
            )
            .unwrap();
        }

        // Month/day decimal digits index this 10-byte U lookup.
        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== DATE DIGIT U TABLE @ MGAME +0x01bd8 ===").unwrap();
        for digit in 0..10usize {
            let off = 0x1bd8 + digit;
            let u = mgame[off];
            writeln!(
                &mut report,
                "digit[{digit}] +0x{off:05x}: u={u:3}  row0-cell-{}",
                usize::from(u) / 16
            )
            .unwrap();
        }

        writeln!(&mut report).unwrap();
        writeln!(
            &mut report,
            "bytes +0x01be2..+0x01be3 = {:02x} {:02x}",
            mgame[0x1be2], mgame[0x1be3]
        )
        .unwrap();

        // +0x1857 is read, doubled, and used to index U/V separately at
        // +0x1be4/+0x1be5. Dump seven pairs (one per weekday).
        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== WEEKDAY UV TABLE @ MGAME +0x01be4 ===").unwrap();
        for weekday in 0..7usize {
            let off = 0x1be4 + weekday * 2;
            let u = mgame[off];
            let v = mgame[off + 1];
            writeln!(
                &mut report,
                "weekday[{weekday}] +0x{off:05x}: u={u:3} v={v:3}  {}",
                pair_cell(u, v)
            )
            .unwrap();
        }

        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== DATE ROUTINE CONFIRMATION ===").unwrap();
        writeln!(&mut report, "month state byte   : 0x801f1855").unwrap();
        writeln!(&mut report, "day state byte     : 0x801f1856").unwrap();
        writeln!(&mut report, "weekday state byte : 0x801f1857").unwrap();
        writeln!(&mut report, "fixed UV table     : MGAME +0x01bd0").unwrap();
        writeln!(&mut report, "digit U table      : MGAME +0x01bd8").unwrap();
        writeln!(&mut report, "weekday UV table   : MGAME +0x01be4").unwrap();

        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== DISASSEMBLY MGAME +0x13000..+0x131b8 ===").unwrap();
        for offset in (0x13000usize..=0x131b8usize).step_by(4) {
            let word = u32::from_le_bytes(
                mgame[offset..offset + 4]
                    .try_into()
                    .expect("instruction bytes")
            );
            let pc = MGAME_BASE + offset as u32;
            match decode(word, pc) {
                Ok(instruction) => {
                    writeln!(
                        &mut report,
                        "+0x{offset:05x} 0x{pc:08x} {word:08x} {instruction:?}"
                    )
                    .unwrap();
                }
                Err(_) => {
                    writeln!(
                        &mut report,
                        "+0x{offset:05x} 0x{pc:08x} {word:08x} <decode failed>"
                    )
                    .unwrap();
                }
            }
        }

        // Also fingerprint row-0 cells 0..31. This lets the semantic asset map
        // and UV tables be cross-checked without guessing.
        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== MGCOCK ROW-0 16x24 CELL HASHES ===").unwrap();
        for index in 0..32usize {
            let cell = crate::tim::Cell {
                x: index * 16,
                y: 0,
                width: 16,
                height: 24,
            };
            let pixels =
                crate::tim::read_indexed_cell_in_prefix(&mgcock, 0, cell)?;
            writeln!(
                &mut report,
                "cell[{index:02}] x={:3} sha={}",
                index * 16,
                crate::pipeline::sha256_bytes(&pixels)
            )
            .unwrap();
        }

        fs::write(&output, &report)?;

        println!("DATE_PROBE_REPORT={}", output.display());
        println!("DATE_PROBE_MGAME_SHA={}", crate::pipeline::sha256_bytes(&mgame));
        println!(
            "DATE_PROBE_MGCOCK_DECODED_SHA={}",
            crate::pipeline::sha256_bytes(&mgcock)
        );

        // Echo the compact tables to the test output so Ryan can paste the
        // whole PowerShell response without opening the report manually.
        println!("FIXED_UV={:?}", &mgame[0x1bd0..0x1bd8]);
        println!("DIGIT_U={:?}", &mgame[0x1bd8..0x1be2]);
        println!("WEEKDAY_UV={:?}", &mgame[0x1be4..0x1bf2]);

        Ok(())
    }
}

'@

$Injected = $OriginalSource.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine
$Succeeded = $false

try {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $Injected,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "Running source-bound dynamic-date renderer probe..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_dynamic_date_probe_v1",
            "--", "--nocapture"
        )
    }
    finally {
        Pop-Location
    }

    $Succeeded = $true
}
catch {
    Write-Host ""
    Write-Host "FIRST PROBE ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw
}
finally {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $OriginalSource,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not $Succeeded) {
    Fail "Dynamic Date Probe v1 did not complete."
}
if (-not (Test-Path $ReportPath)) {
    Fail "Probe completed but renderer report is missing."
}

Write-Host ""
Write-Host "=== DYNAMIC DATE RENDERER MAP ===" -ForegroundColor Yellow
Get-Content $ReportPath

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "DYNAMIC DATE PROBE V1 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Renderer report:"
Write-Host $ReportPath
Write-Host ""
Write-Host "Calendar asset map:"
Write-Host $AssetReportPath
Write-Host ""
Write-Host "Nothing in the BIN was modified." -ForegroundColor Green

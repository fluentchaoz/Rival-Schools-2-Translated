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

$OutputRoot = Join-Path $Upstream "work\english-road-to-batsu-dynamic-date-slots-v3"
$ReportPath = Join-Path $OutputRoot "dynamic-date-first-page-slots-v3.txt"

Write-Host ""
Write-Host "Justice Gakuen English Project - Dynamic Date Slot Probe v3" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream directory." }
if (-not (Test-Path $SourcePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $InputBin)) { Fail "Missing current SCHOOL GATE fit BIN." }

$InputHash = (Get-FileHash $InputBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Current base BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Current base is not the exact a2e158... SCHOOL GATE fit build."
}
Write-Host "Base hash verified." -ForegroundColor Green

$Marker = "// ENGLISH_PROJECT_DYNAMIC_DATE_SLOT_PROBE_V3"
$OriginalSource = [System.IO.File]::ReadAllText($SourcePath)
if ($OriginalSource.Contains($Marker)) {
    Fail "A stale slot-probe injection is already present in source_disc.rs."
}

$Rust = @'

// ENGLISH_PROJECT_DYNAMIC_DATE_SLOT_PROBE_V3
#[cfg(test)]
mod english_dynamic_date_slot_probe_v3 {
    use std::collections::BTreeMap;
    use std::fmt::Write as _;
    use std::fs;
    use std::path::Path;

    use anyhow::{Result, ensure};

    const INPUT_HASH: &str =
        "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1";

    #[test]
    fn english_dynamic_date_slot_probe_v3() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-road-to-batsu-opening-school-gate-fit/build/justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
        );
        let output_root =
            root.join("work/english-road-to-batsu-dynamic-date-slots-v3");
        let output =
            output_root.join("dynamic-date-first-page-slots-v3.txt");

        ensure!(input.is_file(), "current base BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "current base BIN hash changed"
        );
        fs::create_dir_all(&output_root)?;

        let (_, mgcock_stored) =
            crate::disc::rebuild::read_record(&input, "DAT2/MGCOCK.TIZ")?;
        let mgcock = crate::compression::decompress(&mgcock_stored, true)?;
        let tim = crate::tim::parse_4bpp_prefix(&mgcock)?;
        ensure!(
            tim.pixel_width() == 1024 && tim.image_height == 256,
            "unexpected MGCOCK geometry"
        );

        let mut report = String::new();
        writeln!(&mut report, "Justice Gakuen 2 first-page date slot probe v3").unwrap();
        writeln!(&mut report).unwrap();
        writeln!(
            &mut report,
            "MGCOCK_DECODED_SHA256={}",
            crate::pipeline::sha256_bytes(&mgcock)
        )
        .unwrap();
        writeln!(&mut report).unwrap();
        writeln!(
            &mut report,
            "Scanning 16x24 cells with x=0..240 (same PS1 texture page as native date glyphs)."
        )
        .unwrap();

        let mut blank = Vec::<(usize, usize)>::new();

        // 10 rows fit inside 256px height: y = 0,24,...,216.
        for row in 0..10usize {
            writeln!(&mut report).unwrap();
            writeln!(&mut report, "=== ROW {row} y={} ===", row * 24).unwrap();

            for col in 0..16usize {
                let cell = crate::tim::Cell {
                    x: col * 16,
                    y: row * 24,
                    width: 16,
                    height: 24,
                };
                let pixels =
                    crate::tim::read_indexed_cell_in_prefix(&mgcock, 0, cell)?;

                let mut histogram = BTreeMap::<u8, usize>::new();
                for &p in &pixels {
                    *histogram.entry(p).or_default() += 1;
                }
                let clear = histogram
                    .iter()
                    .max_by_key(|(index, count)| (**count, std::cmp::Reverse(**index)))
                    .map(|(index, _)| *index)
                    .unwrap_or(0);
                let ink = pixels.iter().filter(|&&p| p != clear).count();

                if ink == 0 {
                    blank.push((col, row));
                    writeln!(
                        &mut report,
                        "BLANK col={col:02} row={row:02} u={:3} v={:3} cell=({},{} 16x24)",
                        col * 16,
                        row * 24,
                        col * 16,
                        row * 24
                    )
                    .unwrap();
                } else {
                    writeln!(
                        &mut report,
                        "USED  col={col:02} row={row:02} u={:3} v={:3} ink={ink:3} sha={}",
                        col * 16,
                        row * 24,
                        crate::pipeline::sha256_bytes(&pixels)
                    )
                    .unwrap();
                }
            }
        }

        writeln!(&mut report).unwrap();
        writeln!(&mut report, "=== BLANK SAME-PAGE CELLS ===").unwrap();
        for (col, row) in &blank {
            writeln!(
                &mut report,
                "col={col:02} row={row:02} => UV=({}, {})",
                col * 16,
                row * 24
            )
            .unwrap();
        }
        writeln!(&mut report, "blank_count={}", blank.len()).unwrap();

        fs::write(&output, &report)?;

        println!("DATE_SLOT_REPORT={}", output.display());
        println!("DATE_SLOT_BLANK_COUNT={}", blank.len());
        for (col, row) in blank.iter().take(24) {
            println!("DATE_SLOT_BLANK UV=({}, {})", col * 16, row * 24);
        }

        Ok(())
    }
}

'@

$Injected =
    $OriginalSource.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine

$Succeeded = $false
try {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $Injected,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "Scanning first texture page for safe 16x24 date slots..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_dynamic_date_slot_probe_v3",
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

if (-not $Succeeded) { Fail "Slot probe did not complete." }
if (-not (Test-Path $ReportPath)) { Fail "Slot probe report is missing." }

Write-Host ""
Write-Host "=== FIRST-PAGE DATE SLOT REPORT ===" -ForegroundColor Yellow
Get-Content $ReportPath

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "DYNAMIC DATE SLOT PROBE V3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Nothing in the BIN was modified." -ForegroundColor Green

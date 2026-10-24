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

$OutputRoot = Join-Path $Upstream "work\english-road-to-batsu-calendar-punctuation-v4"
$ReportPath = Join-Path $OutputRoot "calendar-punctuation-v4.txt"

Write-Host ""
Write-Host "Justice Gakuen English Project - Calendar Punctuation Probe v4" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream directory." }
if (-not (Test-Path $SourcePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $InputBin)) { Fail "Missing current clean SCHOOL GATE fit BIN." }

$InputHash = (Get-FileHash $InputBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Current clean base SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Base is not the exact a2e158... SCHOOL GATE fit build."
}
Write-Host "Base hash verified." -ForegroundColor Green

$Marker = "// ENGLISH_PROJECT_CALENDAR_PUNCTUATION_PROBE_V4"
$OriginalSource = [System.IO.File]::ReadAllText($SourcePath)
if ($OriginalSource.Contains($Marker)) {
    Fail "A stale punctuation-probe injection is already present."
}

$Rust = @'

// ENGLISH_PROJECT_CALENDAR_PUNCTUATION_PROBE_V4
#[cfg(test)]
mod english_calendar_punctuation_probe_v4 {
    use std::collections::BTreeMap;
    use std::fmt::Write as _;
    use std::fs;
    use std::path::Path;

    use anyhow::{Result, ensure};

    const INPUT_HASH: &str =
        "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1";

    fn render_ascii(pixels: &[u8], clear: u8) -> Vec<String> {
        let mut lines = Vec::new();
        for y in 0..24usize {
            let mut line = String::with_capacity(16);
            for x in 0..16usize {
                let p = pixels[y * 16 + x];
                line.push(if p == clear { '.' } else { '#' });
            }
            lines.push(line);
        }
        lines
    }

    #[test]
    fn english_calendar_punctuation_probe_v4() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-road-to-batsu-opening-school-gate-fit/build/justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
        );
        let output_root =
            root.join("work/english-road-to-batsu-calendar-punctuation-v4");
        let output = output_root.join("calendar-punctuation-v4.txt");

        ensure!(input.is_file(), "clean SCHOOL GATE fit BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "clean SCHOOL GATE fit BIN hash changed"
        );
        fs::create_dir_all(&output_root)?;

        let (_, stored) =
            crate::disc::rebuild::read_record(&input, "DAT2/MGCOCK.TIZ")?;
        let decoded = crate::compression::decompress(&stored, true)?;

        let mut report = String::new();
        writeln!(&mut report, "Justice Gakuen 2 calendar punctuation probe v4").unwrap();
        writeln!(&mut report).unwrap();
        writeln!(
            &mut report,
            "Goal: identify an existing slash-like glyph without modifying MGCOCK."
        )
        .unwrap();
        writeln!(
            &mut report,
            "Known row1 cells: col0=day/Sunday, col1='(', col2=')'."
        )
        .unwrap();

        // The low-ink cells immediately after the date punctuation are the
        // best candidates. Include enough neighbors to make identification
        // obvious rather than guessing from hashes.
        for col in 3usize..=10usize {
            let cell = crate::tim::Cell {
                x: col * 16,
                y: 24,
                width: 16,
                height: 24,
            };
            let pixels =
                crate::tim::read_indexed_cell_in_prefix(&decoded, 0, cell)?;
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

            writeln!(&mut report).unwrap();
            writeln!(
                &mut report,
                "=== ROW1 COL {col:02}  UV=({},24)  ink={ink} clear={clear} sha={} ===",
                col * 16,
                crate::pipeline::sha256_bytes(&pixels)
            )
            .unwrap();
            for line in render_ascii(&pixels, clear) {
                writeln!(&mut report, "{line}").unwrap();
            }
        }

        // Also include the two native parentheses for visual scale reference.
        for (name, col) in [("LEFT_PAREN", 1usize), ("RIGHT_PAREN", 2usize)] {
            let cell = crate::tim::Cell {
                x: col * 16,
                y: 24,
                width: 16,
                height: 24,
            };
            let pixels =
                crate::tim::read_indexed_cell_in_prefix(&decoded, 0, cell)?;
            let mut histogram = BTreeMap::<u8, usize>::new();
            for &p in &pixels {
                *histogram.entry(p).or_default() += 1;
            }
            let clear = histogram
                .iter()
                .max_by_key(|(index, count)| (**count, std::cmp::Reverse(**index)))
                .map(|(index, _)| *index)
                .unwrap_or(0);

            writeln!(&mut report).unwrap();
            writeln!(&mut report, "=== REFERENCE {name} UV=({},24) ===", col * 16).unwrap();
            for line in render_ascii(&pixels, clear) {
                writeln!(&mut report, "{line}").unwrap();
            }
        }

        fs::write(&output, &report)?;
        println!("PUNCTUATION_REPORT={}", output.display());
        println!("PUNCTUATION_PROBE_COMPLETE=1");
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
    Write-Host "Reading likely native punctuation cells..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_calendar_punctuation_probe_v4",
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

if (-not $Succeeded) { Fail "Punctuation probe did not complete." }
if (-not (Test-Path $ReportPath)) { Fail "Punctuation report is missing." }

Write-Host ""
Write-Host "=== CALENDAR PUNCTUATION MAP ===" -ForegroundColor Yellow
Get-Content $ReportPath

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "CALENDAR PUNCTUATION PROBE V4 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Nothing in the BIN was modified." -ForegroundColor Green

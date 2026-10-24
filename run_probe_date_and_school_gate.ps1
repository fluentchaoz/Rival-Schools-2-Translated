param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder
)

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
$InputBin = Join-Path $Upstream "work\english-road-to-batsu-blue-title\build\justice-gakuen2-road-to-batsu-blue-title.bin"
$ExpectedInputHash = "ad068a54820b62bd246538e49776291512b88cab6447127fdd93ee6d4392dec4"
$ProbeRoot = Join-Path $Upstream "work\english-road-to-batsu-date-location-probe"
$CalendarReport = Join-Path $ProbeRoot "calendar-probe.txt"
$LocationAudit = Join-Path $ProbeRoot "location-audit"
$ContactSheet = Join-Path $ProbeRoot "location-strips-contact-sheet.png"

if (-not (Test-Path $Upstream)) { Fail "Missing upstream project directory." }
if (-not (Test-Path $InputBin)) { Fail "Missing successful blue-title BIN." }

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Input BIN is not the exact successful blue-title build."
}

$SourceCues = @(Get-ChildItem -LiteralPath $RomFolder -Filter *.cue -File)
if ($SourceCues.Count -ne 1) {
    Fail ("Expected exactly one source CUE in {0}; found {1}." -f $RomFolder, $SourceCues.Count)
}
$SourceCue = $SourceCues[0].FullName

if (Test-Path $ProbeRoot) {
    Remove-Item -LiteralPath $ProbeRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $ProbeRoot | Out-Null

$ProbeBinRs = Join-Path $Upstream "src\bin\english_calendar_probe.rs"

$Rust = @'
use std::collections::BTreeMap;
use std::fs;
use std::path::PathBuf;

use anyhow::{Context, Result, ensure};
use psx_r3000a::{Instruction, decode};

use justice_gakuen2_kr::compression;
use justice_gakuen2_kr::disc::rebuild;
use justice_gakuen2_kr::pipeline::sha256_bytes;
use justice_gakuen2_kr::tim::{Cell, parse_4bpp_prefix, read_indexed_cell_in_prefix};

const MGAME_BASE: u32 = 0x800a_2000;

fn main() -> Result<()> {
    let mut args = std::env::args_os().skip(1);
    let input = PathBuf::from(args.next().context("missing input BIN")?);
    let output = PathBuf::from(args.next().context("missing output report")?);
    ensure!(args.next().is_none(), "unexpected extra arguments");

    let (_, mgame) = rebuild::read_record(&input, "DAT1/MGAME.BIN")?;
    let (_, mgcock_stored) = rebuild::read_record(&input, "DAT2/MGCOCK.TIZ")?;
    let mgcock = compression::decompress(&mgcock_stored, false)?;
    let tim = parse_4bpp_prefix(&mgcock)?;
    ensure!(
        tim.pixel_width() == 1024 && tim.image_height == 256,
        "unexpected MGCOCK geometry"
    );

    let mut report = String::new();
    macro_rules! line {
        ($($arg:tt)*) => {{
            report.push_str(&format!($($arg)*));
            report.push('\n');
        }};
    }

    line!("Justice Gakuen 2 English calendar renderer probe");
    line!("MGAME bytes: {}", mgame.len());
    line!("MGCOCK decoded SHA-256: {}", sha256_bytes(&mgcock));
    line!();

    line!("=== MGAME loads of current month/day state bytes ===");
    let mut anchors = Vec::<usize>::new();
    for offset in (0..mgame.len().saturating_sub(3)).step_by(4) {
        let word = u32::from_le_bytes(mgame[offset..offset + 4].try_into()?);
        let pc = MGAME_BASE + offset as u32;
        let Ok(instruction) = decode(word, pc) else {
            continue;
        };
        if matches!(
            instruction,
            Instruction::Lbu { offset: 0x1855, .. }
                | Instruction::Lbu { offset: 0x1856, .. }
        ) {
            anchors.push(offset);
            line!(
                "anchor file +0x{offset:05x} runtime 0x{pc:08x}: {instruction:?}"
            );
        }
    }
    line!("anchor count: {}", anchors.len());

    for anchor in &anchors {
        line!();
        line!("--- disassembly around file +0x{anchor:05x} ---");
        let start = anchor.saturating_sub(32 * 4) & !3;
        let end = (anchor + 48 * 4).min(mgame.len().saturating_sub(4));
        for offset in (start..=end).step_by(4) {
            let word = u32::from_le_bytes(mgame[offset..offset + 4].try_into()?);
            let pc = MGAME_BASE + offset as u32;
            match decode(word, pc) {
                Ok(instruction) => {
                    let marker = if offset == *anchor { ">>" } else { "  " };
                    line!(
                        "{marker} +0x{offset:05x} 0x{pc:08x} {word:08x} {instruction:?}"
                    );
                }
                Err(_) => {
                    line!("   +0x{offset:05x} 0x{pc:08x} {word:08x} <decode failed>");
                }
            }
        }
    }

    line!();
    line!("=== Candidate date-digit UV tables in MGAME ===");
    let pair_pattern = [
        0u8, 0, 16, 0, 32, 0, 48, 0, 64, 0,
        80, 0, 96, 0, 112, 0, 128, 0, 144, 0,
    ];
    let u_pattern = [0u8, 16, 32, 48, 64, 80, 96, 112, 128, 144];
    let zero_last = [16u8, 32, 48, 64, 80, 96, 112, 128, 144, 0];

    for (name, pattern) in [
        ("uv-pairs", pair_pattern.as_slice()),
        ("u-sequence", u_pattern.as_slice()),
        ("u-sequence-zero-last", zero_last.as_slice()),
    ] {
        let matches = mgame
            .windows(pattern.len())
            .enumerate()
            .filter_map(|(offset, bytes)| (bytes == pattern).then_some(offset))
            .collect::<Vec<_>>();
        line!("{name}: {:?}", matches.iter().map(|o| format!("+0x{o:05x}")).collect::<Vec<_>>());
    }

    line!();
    line!("=== MGCOCK first-row 16x24 cells ===");
    line!("Cells 0..9 are the source-bound date digits. Later cells are what we need to classify.");
    for index in 0..28usize {
        let cell = Cell {
            x: index * 16,
            y: 0,
            width: 16,
            height: 24,
        };
        let pixels = read_indexed_cell_in_prefix(&mgcock, 0, cell)?;
        let mut histogram = BTreeMap::<u8, usize>::new();
        for &p in &pixels {
            *histogram.entry(p).or_default() += 1;
        }
        let clear = histogram
            .iter()
            .max_by_key(|(index, count)| (**count, std::cmp::Reverse(**index)))
            .map(|(index, _)| *index)
            .unwrap_or(0);

        let mut left = 16usize;
        let mut top = 24usize;
        let mut right = 0usize;
        let mut bottom = 0usize;
        let mut ink = 0usize;
        for y in 0..24 {
            for x in 0..16 {
                if pixels[y * 16 + x] != clear {
                    ink += 1;
                    left = left.min(x);
                    top = top.min(y);
                    right = right.max(x + 1);
                    bottom = bottom.max(y + 1);
                }
            }
        }
        if ink == 0 {
            left = 0;
            top = 0;
            right = 0;
            bottom = 0;
        }

        line!();
        line!(
            "CELL {index:02} x={} sha={} clear={} ink={} bbox=[{left},{top},{right},{bottom}]",
            index * 16,
            sha256_bytes(&pixels),
            clear,
            ink
        );
        for y in 0..24 {
            let mut row = String::with_capacity(16);
            for x in 0..16 {
                row.push(if pixels[y * 16 + x] == clear { '.' } else { '#' });
            }
            line!("{row}");
        }
    }

    fs::write(&output, report)?;
    println!("CALENDAR_PROBE={}", output.display());
    println!("MONTH_DAY_LBU_ANCHORS={}", anchors.len());
    Ok(())
}
'@

[System.IO.File]::WriteAllText(
    $ProbeBinRs,
    $Rust,
    (New-Object System.Text.UTF8Encoding($false))
)

Push-Location $Upstream
try {
    Write-Host ""
    Write-Host "Justice Gakuen English Project - Date + School Gate Probe" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[1/4] Building calendar renderer probe..."
    Run-Native "cargo" @("build", "--release", "--bin", "english_calendar_probe")

    Write-Host ""
    Write-Host "[2/4] Probing current date sprites and MGAME consumers..."
    $CalendarExe = Join-Path $Upstream "target\release\english_calendar_probe.exe"
    Run-Native $CalendarExe @($InputBin, $CalendarReport)

    Write-Host ""
    Write-Host "[3/4] Auditing diary-scene location graphics..."
    Run-Native "cargo" @("build", "--release", "--bin", "justice-gakuen2-kr")
    $MainExe = Join-Path $Upstream "target\release\justice-gakuen2-kr.exe"
    Run-Native $MainExe @(
        "audit-diary-location-graphics",
        "--cue", $SourceCue,
        "--output-dir", $LocationAudit
    )

    Write-Host ""
    Write-Host "[4/4] Building distinct location-strip contact sheet..."

    $CataloguePath = Join-Path $LocationAudit "catalogue.json"
    $PreviewIndexPath = Join-Path $LocationAudit "catalogue-previews.json"
    if (-not (Test-Path $CataloguePath)) { Fail "Location audit did not write catalogue.json." }
    if (-not (Test-Path $PreviewIndexPath)) { Fail "Location audit did not write catalogue-previews.json." }

    $Catalogue = Get-Content -LiteralPath $CataloguePath -Raw | ConvertFrom-Json
    $PreviewIndex = Get-Content -LiteralPath $PreviewIndexPath -Raw | ConvertFrom-Json

    $PreviewByIndex = @{}
    foreach ($Entry in $PreviewIndex.entries) {
        $PreviewByIndex[[int]$Entry.member_index] = [string]$Entry.preview_file
    }

    $Groups = @{}
    foreach ($Member in $Catalogue.members) {
        if ($null -eq $Member.location_block_sha256) { continue }
        $Hash = [string]$Member.location_block_sha256
        if (-not $Groups.ContainsKey($Hash)) {
            $Groups[$Hash] = New-Object System.Collections.ArrayList
        }
        [void]$Groups[$Hash].Add([int]$Member.index)
    }

    Add-Type -AssemblyName System.Drawing

    $Scale = 3
    $CropW = 128
    $CropH = 24
    $LabelH = 34
    $TileW = $CropW * $Scale
    $TileH = $CropH * $Scale + $LabelH
    $Columns = 2
    $Hashes = @($Groups.Keys | Sort-Object)
    $Rows = [Math]::Ceiling($Hashes.Count / [double]$Columns)
    $SheetW = $Columns * $TileW
    $SheetH = [int]$Rows * $TileH

    $Sheet = New-Object System.Drawing.Bitmap($SheetW, $SheetH)
    $G = [System.Drawing.Graphics]::FromImage($Sheet)
    $G.Clear([System.Drawing.Color]::Black)
    $G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half

    $Font = New-Object System.Drawing.Font("Consolas", 9)
    $Brush = [System.Drawing.Brushes]::White

    try {
        for ($i = 0; $i -lt $Hashes.Count; $i++) {
            $Hash = $Hashes[$i]
            $Members = @($Groups[$Hash])
            $Representative = [int]$Members[0]
            if (-not $PreviewByIndex.ContainsKey($Representative)) { continue }

            $PreviewPath = Join-Path $LocationAudit $PreviewByIndex[$Representative]
            if (-not (Test-Path $PreviewPath)) { continue }

            $Image = [System.Drawing.Image]::FromFile($PreviewPath)
            try {
                if ($Image.Width -lt 128 -or $Image.Height -lt 244) { continue }

                $Col = $i % $Columns
                $Row = [Math]::Floor($i / $Columns)
                $X = $Col * $TileW
                $Y = $Row * $TileH

                $Label = ("hash {0}  members {1}" -f $Hash.Substring(0,8), (($Members | Sort-Object) -join ","))
                $G.DrawString($Label, $Font, $Brush, $X + 2, $Y + 2)

                $Src = New-Object System.Drawing.Rectangle(0, 220, 128, 24)
                $Dst = New-Object System.Drawing.Rectangle(
                    $X,
                    $Y + $LabelH,
                    $CropW * $Scale,
                    $CropH * $Scale
                )
                $G.DrawImage($Image, $Dst, $Src, [System.Drawing.GraphicsUnit]::Pixel)
            }
            finally {
                $Image.Dispose()
            }
        }

        $Sheet.Save($ContactSheet, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $Font.Dispose()
        $G.Dispose()
        $Sheet.Dispose()
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "DATE + SCHOOL GATE PROBE COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Calendar probe:" -ForegroundColor Yellow
    Write-Host $CalendarReport
    Write-Host ""
    Write-Host "Location-strip contact sheet:" -ForegroundColor Yellow
    Write-Host $ContactSheet
    Write-Host ""
    Write-Host "Paste the console output and send a screenshot of the contact sheet." -ForegroundColor Cyan
    Write-Host "The next patch can then be exact for 4/1 (THU) and SCHOOL GATE." -ForegroundColor Cyan
}
finally {
    Pop-Location
}

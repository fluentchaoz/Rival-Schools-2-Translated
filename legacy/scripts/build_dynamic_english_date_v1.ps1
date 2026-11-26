param(
    [string]$FontPath = ""
)

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

$BaseBin = Join-Path $Upstream "work\english-road-to-batsu-opening-school-gate-fit\build\justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
$ExpectedBaseHash = "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1"

$OutputDir = Join-Path $Upstream "work\english-road-to-batsu-dynamic-date-v1\build"
$OutputBin = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-dynamic-date-v1.bin"
$OutputCue = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-dynamic-date-v1.cue"
$ReportPath = Join-Path $OutputDir "dynamic-date-v1-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - DYNAMIC ENGLISH DATE v1" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream directory beside this script." }
if (-not (Test-Path $SourcePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $BaseBin)) { Fail "Missing current SCHOOL GATE fit BIN." }

$BaseHash = (Get-FileHash $BaseBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Base BIN SHA-256: {0}" -f $BaseHash)
if ($BaseHash -ne $ExpectedBaseHash) {
    Fail "Base BIN is not the exact a2e158... SCHOOL GATE fit build. Nothing was changed."
}
Write-Host "Base hash verified." -ForegroundColor Green

if ([string]::IsNullOrWhiteSpace($FontPath)) {
    foreach ($Candidate in @(
        "C:\Windows\Fonts\arialbd.ttf",
        "C:\Windows\Fonts\segoeuib.ttf",
        "C:\Windows\Fonts\arial.ttf",
        "C:\Windows\Fonts\segoeui.ttf"
    )) {
        if (Test-Path $Candidate) {
            $FontPath = $Candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($FontPath) -or -not (Test-Path $FontPath)) {
    Fail "Could not find a usable Arial/Segoe UI font. Re-run with -FontPath pointing to an installed .ttf."
}
Write-Host ("Calendar font: {0}" -f $FontPath)

$Marker = "// ENGLISH_PROJECT_DYNAMIC_ENGLISH_DATE_V1"
$OriginalSource = [System.IO.File]::ReadAllText($SourcePath)

if ($OriginalSource.Contains($Marker)) {
    Fail "A stale dynamic-date v1 injection is already present in source_disc.rs."
}

$Rust = @'

// ENGLISH_PROJECT_DYNAMIC_ENGLISH_DATE_V1
#[cfg(test)]
mod english_dynamic_english_date_v1 {
    use std::fs;
    use std::path::Path;

    use anyhow::{Context, Result, ensure};
    use serde_json::json;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::tim::{Cell, read_indexed_cell_in_prefix, write_indexed_cell_in_prefix};

    const INPUT_HASH: &str =
        "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1";
    const MGAME_SHA256: &str =
        "887c7c1775db5a18aed19661a08d109a5f35c54303259b21c7d6560ef1a3baba";
    const MGCOCK_STORED_SHA256: &str =
        "241d3ba8b25aef281c932f9bd64c0ffb84693abf72ad7b1d5cde852d4b655285";
    const MGCOCK_DECODED_SHA256: &str =
        "bc81dda96d98a4ed06b37db9415636430db630d13217d2275059bb306d9fb655";

    const ORIGINAL_WEEKDAY_UV: [u8; 14] = [
        0, 24, 160, 0, 176, 0, 192, 0, 208, 0, 224, 0, 240, 0,
    ];
    const PATCHED_WEEKDAY_UV_PREFIX: [u8; 4] = [176, 192, 192, 192];

    const CELL_MONTH_MONDAY_HASH: &str =
        "72044f0fba7f9619e069219b58c60039508a2d15169a7da66bfc4fc5c873587d";
    const CELL_TUE_HASH: &str =
        "6230067be3f2d0a8bf3ce04c67beb14cec7463cf1239e8089e4f9be9257b5175";
    const CELL_WED_HASH: &str =
        "511086e8e68a2155ff3df3f205aa57b5fc0a28456eb6ca1fb896f45bcc1fdb0f";
    const CELL_THU_HASH: &str =
        "0cdb5adea141f7f3102575ab0ee9c33ea811bb183cccf2d2af8d2d35222c20b8";
    const CELL_FRI_HASH: &str =
        "a7d9b5ee3f5a9b804d8057bffd471a256d693ecfcdbe03a0446c92cac0f371c3";
    const CELL_SAT_HASH: &str =
        "41f7730ea585e0d5356666639c344f411e36cd4cdfab59525ffdeb403c352bc5";
    const CELL_DAY_SUNDAY_HASH: &str =
        "795b265fe0b306e9acf095d7ea178b86931c8b2f9a776df13fb4cb698bb7dc85";
    const BLANK_CELL_HASH: &str =
        "a1a4f5721c1c4610af7f71078f3a68c330536d679803b0e0507ee8dc10c5dfca";

    const MONTH_SUFFIX: Cell = Cell { x: 160, y: 0, width: 16, height: 24 };
    const TUE_CELL: Cell = Cell { x: 176, y: 0, width: 16, height: 24 };
    const WED_CELL: Cell = Cell { x: 192, y: 0, width: 16, height: 24 };
    const THU_CELL: Cell = Cell { x: 208, y: 0, width: 16, height: 24 };
    const FRI_CELL: Cell = Cell { x: 224, y: 0, width: 16, height: 24 };
    const SAT_CELL: Cell = Cell { x: 240, y: 0, width: 16, height: 24 };

    const DAY_SUFFIX: Cell = Cell { x: 0, y: 24, width: 16, height: 24 };

    // Safe same-texture-page blank cells proven by Dynamic Date Slot Probe v3.
    const SUN_CELL: Cell = Cell { x: 176, y: 192, width: 16, height: 24 };
    const MON_CELL: Cell = Cell { x: 192, y: 192, width: 16, height: 24 };

    fn verify_cell(decoded: &[u8], cell: Cell, expected: &str, name: &str) -> Result<()> {
        let pixels = read_indexed_cell_in_prefix(decoded, 0, cell)?;
        ensure!(
            crate::pipeline::sha256_bytes(&pixels) == expected,
            "{name} source cell changed"
        );
        Ok(())
    }

    fn raster(
        font: &IndexedTextRasterizer,
        text: &str,
        cell: Cell,
        font_px: f32,
        tracking_px: f32,
    ) -> Result<Vec<u8>> {
        Ok(font
            .rasterize_shifted_with_coverage_ramp(
                text,
                cell.width,
                cell.height,
                font_px,
                tracking_px,
                0,
                0,
                1,
                15,
                HorizontalTextAlignment::Center,
            )?
            .pixels)
    }

    fn select_weekday_font(
        font: &IndexedTextRasterizer,
    ) -> Result<(f32, f32, Vec<Vec<u8>>)> {
        let names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        for (font_px, tracking_px) in [
            (9.0_f32, -1.0_f32),
            (8.5, -1.0),
            (8.0, -0.75),
            (7.5, -0.5),
            (7.0, -0.5),
            (6.5, -0.25),
        ] {
            let mut rendered = Vec::new();
            let mut all_fit = true;
            for name in names {
                match raster(font, name, TUE_CELL, font_px, tracking_px) {
                    Ok(pixels) => rendered.push(pixels),
                    Err(_) => {
                        all_fit = false;
                        break;
                    }
                }
            }
            if all_fit {
                return Ok((font_px, tracking_px, rendered));
            }
        }
        anyhow::bail!("SUN..SAT could not fit a 16x24 calendar sprite")
    }

    #[test]
    fn english_dynamic_english_date_v1() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("justice-gakuen2-dynamic-date-large-stack".to_string())
            .stack_size(64 * 1024 * 1024)
            .spawn(run_patch)?;
        match worker.join() {
            Ok(result) => result,
            Err(payload) => std::panic::resume_unwind(payload),
        }
    }

    fn run_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-road-to-batsu-opening-school-gate-fit/build/justice-gakuen2-road-to-batsu-opening-school-gate-fit.bin"
        );

        let output_root = root.join("work/english-road-to-batsu-dynamic-date-v1");
        let build_dir = output_root.join("build");
        let output_bin = build_dir.join("justice-gakuen2-road-to-batsu-dynamic-date-v1.bin");
        let output_cue = build_dir.join("justice-gakuen2-road-to-batsu-dynamic-date-v1.cue");
        let report_path = build_dir.join("dynamic-date-v1-report.json");

        ensure!(input.is_file(), "current SCHOOL GATE fit BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "current SCHOOL GATE fit BIN hash changed"
        );

        let font_path = std::path::PathBuf::from(
            std::env::var("JG_DYNAMIC_DATE_FONT")
                .context("JG_DYNAMIC_DATE_FONT was not provided")?,
        );
        ensure!(font_path.is_file(), "calendar font is missing");

        if output_root.exists() {
            fs::remove_dir_all(&output_root)?;
        }
        fs::create_dir_all(&build_dir)?;

        eprintln!("dynamic-date: reading MGAME.BIN and MGCOCK.TIZ");

        let (_, source_mgame) =
            crate::disc::rebuild::read_record(&input, "DAT1/MGAME.BIN")?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_mgame) == MGAME_SHA256,
            "MGAME.BIN source changed"
        );
        ensure!(
            source_mgame.get(0x1be4..0x1bf2) == Some(ORIGINAL_WEEKDAY_UV.as_slice()),
            "native weekday UV table changed"
        );

        let (_, source_stored) =
            crate::disc::rebuild::read_record(&input, "DAT2/MGCOCK.TIZ")?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_stored) == MGCOCK_STORED_SHA256,
            "MGCOCK.TIZ stored source changed"
        );

        let mut decoded = crate::compression::decompress(&source_stored, true)?;
        ensure!(
            crate::pipeline::sha256_bytes(&decoded) == MGCOCK_DECODED_SHA256,
            "MGCOCK.TIZ decoded source changed"
        );
        let tim = crate::tim::parse_4bpp_prefix(&decoded)?;
        ensure!(
            tim.pixel_width() == 1024 && tim.image_height == 256,
            "unexpected MGCOCK geometry"
        );

        verify_cell(&decoded, MONTH_SUFFIX, CELL_MONTH_MONDAY_HASH, "month/Monday")?;
        verify_cell(&decoded, TUE_CELL, CELL_TUE_HASH, "Tuesday")?;
        verify_cell(&decoded, WED_CELL, CELL_WED_HASH, "Wednesday")?;
        verify_cell(&decoded, THU_CELL, CELL_THU_HASH, "Thursday")?;
        verify_cell(&decoded, FRI_CELL, CELL_FRI_HASH, "Friday")?;
        verify_cell(&decoded, SAT_CELL, CELL_SAT_HASH, "Saturday")?;
        verify_cell(&decoded, DAY_SUFFIX, CELL_DAY_SUNDAY_HASH, "day/Sunday")?;
        verify_cell(&decoded, SUN_CELL, BLANK_CELL_HASH, "SUN spare")?;
        verify_cell(&decoded, MON_CELL, BLANK_CELL_HASH, "MON spare")?;

        let digit_hashes_before = (0..10usize)
            .map(|digit| {
                let cell = Cell { x: digit * 16, y: 0, width: 16, height: 24 };
                Ok(crate::pipeline::sha256_bytes(
                    &read_indexed_cell_in_prefix(&decoded, 0, cell)?
                ))
            })
            .collect::<Result<Vec<_>>>()?;

        // Parentheses remain native and untouched.
        let left_paren = Cell { x: 16, y: 24, width: 16, height: 24 };
        let right_paren = Cell { x: 32, y: 24, width: 16, height: 24 };
        let paren_hashes_before = [
            crate::pipeline::sha256_bytes(&read_indexed_cell_in_prefix(&decoded, 0, left_paren)?),
            crate::pipeline::sha256_bytes(&read_indexed_cell_in_prefix(&decoded, 0, right_paren)?),
        ];

        let font = IndexedTextRasterizer::load(&font_path)?;

        // Replace 月 with "/" for the fixed month suffix.
        let slash_pixels = [18.0_f32, 17.0, 16.0, 15.0, 14.0]
            .into_iter()
            .find_map(|font_px| raster(&font, "/", MONTH_SUFFIX, font_px, 0.0).ok())
            .context("slash did not fit the native month suffix cell")?;
        write_indexed_cell_in_prefix(&mut decoded, 0, MONTH_SUFFIX, &slash_pixels)?;

        // The fixed 日 suffix becomes transparent. Sunday is redirected below.
        let blank = vec![0u8; DAY_SUFFIX.width * DAY_SUFFIX.height];
        write_indexed_cell_in_prefix(&mut decoded, 0, DAY_SUFFIX, &blank)?;

        // Render one shared weekday style so all seven abbreviations match.
        let (weekday_font_px, weekday_tracking_px, weekday_pixels) =
            select_weekday_font(&font)?;
        let weekday_cells = [
            SUN_CELL, MON_CELL, TUE_CELL, WED_CELL, THU_CELL, FRI_CELL, SAT_CELL,
        ];
        let weekday_names = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        for ((name, cell), pixels) in weekday_names
            .into_iter()
            .zip(weekday_cells)
            .zip(weekday_pixels.iter())
        {
            write_indexed_cell_in_prefix(&mut decoded, 0, cell, pixels)?;
            eprintln!(
                "dynamic-date: rendered {name} at UV=({}, {}) font={} tracking={}",
                cell.x, cell.y, weekday_font_px, weekday_tracking_px
            );
        }

        // Prove native dynamic decimal glyphs and parentheses survived exactly.
        for digit in 0..10usize {
            let cell = Cell { x: digit * 16, y: 0, width: 16, height: 24 };
            let after = crate::pipeline::sha256_bytes(
                &read_indexed_cell_in_prefix(&decoded, 0, cell)?
            );
            ensure!(
                after == digit_hashes_before[digit],
                "native date digit {digit} changed"
            );
        }
        ensure!(
            crate::pipeline::sha256_bytes(
                &read_indexed_cell_in_prefix(&decoded, 0, left_paren)?
            ) == paren_hashes_before[0],
            "left parenthesis changed"
        );
        ensure!(
            crate::pipeline::sha256_bytes(
                &read_indexed_cell_in_prefix(&decoded, 0, right_paren)?
            ) == paren_hashes_before[1],
            "right parenthesis changed"
        );

        // Page-safe recompression is required for this fixed-extent runtime record.
        let source_profile =
            crate::paged_compression::source_paged_compression_profile(&source_stored)?;
        let reencoded =
            crate::paged_compression::compress_page_safe_image(&decoded, source_profile)?;
        ensure!(
            crate::compression::decompress(&reencoded, false)? == decoded,
            "MGCOCK recompression roundtrip changed decoded bytes"
        );
        ensure!(
            reencoded.len() <= source_stored.len(),
            "English calendar MGCOCK exceeds the fixed source record"
        );
        let unpadded_mgcock_size = reencoded.len();
        let mut patched_stored = reencoded;
        patched_stored.resize(source_stored.len(), 0);
        ensure!(
            crate::compression::decompress(&patched_stored, true)? == decoded,
            "padded English calendar MGCOCK changed decoded bytes"
        );

        // Redirect weekday state 0=SUN and 1=MON away from the two suffix cells.
        let mut patched_mgame = source_mgame.clone();
        patched_mgame[0x1be4..0x1be8].copy_from_slice(&PATCHED_WEEKDAY_UV_PREFIX);
        ensure!(
            patched_mgame[0x1be8..0x1bf2] == source_mgame[0x1be8..0x1bf2],
            "Tuesday-Saturday UV table changed"
        );
        ensure!(
            source_mgame.iter().zip(&patched_mgame).enumerate().all(|(i, (a, b))| {
                a == b || (0x1be4..0x1be8).contains(&i)
            }),
            "MGAME changed outside Sunday/Monday UV entries"
        );

        eprintln!("dynamic-date: rebuilding MGCOCK.TIZ + MGAME.BIN");

        let replacements = [
            crate::disc::rebuild::FixedRecordReplacement {
                path: "DAT2/MGCOCK.TIZ",
                data: &patched_stored,
            },
            crate::disc::rebuild::FixedRecordReplacement {
                path: "DAT1/MGAME.BIN",
                data: &patched_mgame,
            },
        ];

        let rebuilt =
            crate::disc::rebuild::copy_and_replace_records(&input, &output_bin, &replacements)?;
        ensure!(rebuilt.len() == 2, "disc rebuild did not replace exactly two records");

        let (_, readback_mgame) =
            crate::disc::rebuild::read_record(&output_bin, "DAT1/MGAME.BIN")?;
        let (_, readback_mgcock) =
            crate::disc::rebuild::read_record(&output_bin, "DAT2/MGCOCK.TIZ")?;
        ensure!(readback_mgame == patched_mgame, "MGAME readback differs");
        ensure!(readback_mgcock == patched_stored, "MGCOCK readback differs");
        ensure!(
            crate::compression::decompress(&readback_mgcock, true)? == decoded,
            "MGCOCK decoded readback differs"
        );

        let (changed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(&input, &output_bin)?;
        ensure!(!changed_lbas.is_empty(), "dynamic-date patch changed no sectors");
        ensure!(
            changed_lbas.iter().all(|lba| {
                rebuilt.iter().any(|record| record.target_lbas.contains(lba))
            }),
            "dynamic-date patch changed sectors outside MGAME/MGCOCK"
        );

        let bin_name = output_bin
            .file_name()
            .context("output BIN has no filename")?
            .to_string_lossy();
        fs::write(
            &output_cue,
            format!(
                "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
            ),
        )?;

        let report = json!({
            "kind": "Justice Gakuen 2 dynamic English date prototype v1",
            "input_bin_sha256": INPUT_HASH,
            "output_bin_sha256": output_sha256,
            "output_cue": output_cue.display().to_string(),
            "target_format": "M/D (DDD)",
            "example": "4/1 (THU)",
            "dynamic_month": true,
            "dynamic_day": true,
            "dynamic_weekday": true,
            "month_state": "0x801f1855",
            "day_state": "0x801f1856",
            "weekday_state": "0x801f1857",
            "digit_uv_table": "MGAME +0x01bd8",
            "weekday_uv_table": "MGAME +0x01be4",
            "weekday_redirects": {
                "SUN": [SUN_CELL.x, SUN_CELL.y],
                "MON": [MON_CELL.x, MON_CELL.y]
            },
            "weekday_font_path": font_path.display().to_string(),
            "weekday_font_px": weekday_font_px,
            "weekday_tracking_px": weekday_tracking_px,
            "mgcock_source_stored_sha256": MGCOCK_STORED_SHA256,
            "mgcock_source_decoded_sha256": MGCOCK_DECODED_SHA256,
            "mgcock_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
            "mgcock_patched_decoded_sha256": crate::pipeline::sha256_bytes(&decoded),
            "mgcock_unpadded_size": unpadded_mgcock_size,
            "mgcock_fixed_record_size": source_stored.len(),
            "mgame_source_sha256": MGAME_SHA256,
            "mgame_patched_sha256": crate::pipeline::sha256_bytes(&patched_mgame),
            "mgame_changed_offsets": ["0x01be4", "0x01be5", "0x01be6", "0x01be7"],
            "native_digits_preserved": true,
            "native_parentheses_preserved": true,
            "spare_cell_208_192_left_untouched": true,
            "changed_sector_count": changed_lbas.len(),
            "readback_verified": true
        });
        let mut bytes = serde_json::to_vec_pretty(&report)?;
        bytes.push(b'\n');
        fs::write(&report_path, bytes)?;

        eprintln!("dynamic-date: COMPLETE");
        eprintln!("dynamic-date: output BIN SHA-256 {}", output_sha256);
        eprintln!("dynamic-date: changed raw sectors {}", changed_lbas.len());
        eprintln!("dynamic-date: CUE {}", output_cue.display());
        eprintln!(
            "dynamic-date: weekday font {}px tracking {}",
            weekday_font_px, weekday_tracking_px
        );

        Ok(())
    }
}

'@

$Injected = $OriginalSource.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine
$OldFontEnv = $env:JG_DYNAMIC_DATE_FONT
$Succeeded = $false

try {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $Injected,
        [System.Text.UTF8Encoding]::new($false)
    )
    $env:JG_DYNAMIC_DATE_FONT = $FontPath

    Write-Host ""
    Write-Host "Building real dynamic English calendar layer..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_dynamic_english_date_v1",
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
    Write-Host "FIRST BUILD ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw
}
finally {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $OriginalSource,
        [System.Text.UTF8Encoding]::new($false)
    )
    if ($null -eq $OldFontEnv) {
        Remove-Item Env:JG_DYNAMIC_DATE_FONT -ErrorAction SilentlyContinue
    }
    else {
        $env:JG_DYNAMIC_DATE_FONT = $OldFontEnv
    }
}

if (-not $Succeeded) { Fail "Dynamic English date build did not complete." }
if (-not (Test-Path $OutputBin)) { Fail "Output BIN is missing." }
if (-not (Test-Path $OutputCue)) { Fail "Output CUE is missing." }
if (-not (Test-Path $ReportPath)) { Fail "Verification report is missing." }

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA-256 does not match the Rust verification report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "DYNAMIC ENGLISH DATE BUILD COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ("Weekday font size: {0}px" -f $Report.weekday_font_px)
Write-Host ("Weekday tracking: {0}px" -f $Report.weekday_tracking_px)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Cyan
Write-Host $OutputCue
Write-Host ""
Write-Host "EXPECTED OPENING DATE:" -ForegroundColor Cyan
Write-Host "4/1 (THU)"
Write-Host ""
Write-Host "This build preserves dynamic month/day/weekday state." -ForegroundColor Green

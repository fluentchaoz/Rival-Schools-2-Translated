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
        Fail ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$RustPath = Join-Path $Upstream "src\dialogue_audit\name_entry_font_build.rs"

$MasterBin = Join-Path $Upstream "work\english-mgk04-full-tutorial-v3\build\justice-gakuen2-mgk04-full-tutorial-v3.bin"
$ExpectedMasterHash = "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-form-v3"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"

$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-form-v3.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-form-v3.cue"
$ReportJson = Join-Path $BuildDir "name-entry-form-v3-report.json"
$PreviewPng = Join-Path $PreviewDir "application-form-english-preview.png"

$FontPath = "C:\Windows\Fonts\arial.ttf"

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY FORM ENGLISH v3" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing name_entry_font_build.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing current MGK04 v3 English master BIN." }
if (-not (Test-Path $FontPath)) { Fail "Missing Arial font." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "Current English master hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_NAME_ENTRY_FORM_V3"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale English name-entry form v3 injection already exists."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$FontLiteral = $FontPath.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_NAME_ENTRY_FORM_V3
#[cfg(test)]
mod english_name_entry_form_v3 {
    use anyhow::{Context, Result, ensure};
    use std::fs;
    use std::path::Path;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::tim::{
        Cell, install_indexed_glyph_in_prefix, read_indexed_cell_in_prefix,
    };

    use super::{
        NAME_ENTRY_FONT_PATH, SOURCE_DECODED_SHA256, SOURCE_DECODED_SIZE,
        SOURCE_STORED_SHA256,
    };

    const INPUT: &str = "$MasterLiteral";
    const INPUT_SHA256: &str =
        "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4";
    const FONT: &str = "$FontLiteral";

    #[derive(Clone, Copy)]
    struct Patch {
        id: &'static str,
        text: &'static str,
        cell: Cell,
        font_px: f32,
        tracking_px: f32,
        alignment: HorizontalTextAlignment,
    }

    const PATCHES: &[Patch] = &[
        Patch {
            id: "title",
            text: "ENROLLMENT FORM",
            cell: Cell { x: 150, y: 20, width: 145, height: 32 },
            font_px: 16.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "exam-date",
            text: "EXAM DATE 4/1",
            cell: Cell { x: 315, y: 48, width: 110, height: 20 },
            font_px: 11.0,
            tracking_px: -0.2,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "name",
            text: "NAME",
            cell: Cell { x: 25, y: 78, width: 85, height: 28 },
            font_px: 14.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "last",
            text: "LAST",
            cell: Cell { x: 125, y: 70, width: 42, height: 16 },
            font_px: 10.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Left,
        },
        Patch {
            id: "first",
            text: "FIRST",
            cell: Cell { x: 285, y: 70, width: 44, height: 16 },
            font_px: 10.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Left,
        },
        Patch {
            id: "nickname",
            text: "NICKNAME",
            cell: Cell { x: 25, y: 122, width: 90, height: 24 },
            font_px: 12.0,
            tracking_px: -0.2,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "school",
            text: "SCHOOL",
            cell: Cell { x: 25, y: 160, width: 90, height: 25 },
            font_px: 13.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "sex",
            text: "SEX",
            cell: Cell { x: 25, y: 199, width: 90, height: 25 },
            font_px: 13.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "birth-date",
            text: "BIRTH DATE",
            cell: Cell { x: 25, y: 237, width: 90, height: 25 },
            font_px: 11.0,
            tracking_px: -0.2,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "month",
            text: "M",
            cell: Cell { x: 176, y: 247, width: 20, height: 16 },
            font_px: 10.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "day",
            text: "D",
            cell: Cell { x: 232, y: 247, width: 20, height: 16 },
            font_px: 10.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "exam-site",
            text: "EXAM SITE",
            cell: Cell { x: 315, y: 235, width: 105, height: 15 },
            font_px: 10.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "exam-site-options",
            text: "CAMPUS (O) OTHER ( )",
            cell: Cell { x: 285, y: 251, width: 140, height: 18 },
            font_px: 8.5,
            tracking_px: -0.4,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "best-subject",
            text: "BEST SUBJECT",
            cell: Cell { x: 25, y: 279, width: 95, height: 25 },
            font_px: 11.0,
            tracking_px: -0.3,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "favorite-word",
            text: "FAVORITE WORD",
            cell: Cell { x: 25, y: 319, width: 190, height: 25 },
            font_px: 12.0,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Left,
        },
        Patch {
            id: "footnote",
            text: "* COMPLETE ALL FIELDS",
            cell: Cell { x: 25, y: 358, width: 200, height: 18 },
            font_px: 9.5,
            tracking_px: 0.0,
            alignment: HorizontalTextAlignment::Left,
        },
    ];

    #[test]
    fn english_name_entry_form_v3() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("english-name-entry-form-v3-large-stack".to_string())
            .stack_size(64 * 1024 * 1024)
            .spawn(run_patch)?;
        match worker.join() {
            Ok(result) => result,
            Err(payload) => std::panic::resume_unwind(payload),
        }
    }

    fn native_clear_and_fill(pixels: &[u8]) -> Result<(u8, u8)> {
        let mut counts = [0usize; 16];
        for &pixel in pixels {
            ensure!(pixel < 16, "application-form pixel exceeds 4bpp range");
            counts[usize::from(pixel)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|index| counts[usize::from(*index)])
            .context("application-form region is empty")?;

        let fill = (0u8..16)
            .filter(|index| *index != clear)
            .max_by_key(|index| counts[usize::from(*index)])
            .context("application-form region contains no source ink")?;

        ensure!(
            counts[usize::from(fill)] > 0,
            "application-form region contains no non-background pixels"
        );
        Ok((clear, fill))
    }

    fn run_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = Path::new(INPUT);
        ensure!(input.is_file(), "English master BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(input)? == INPUT_SHA256,
            "English master BIN hash changed"
        );

        let output_root = root.join("work/english-name-entry-form-v3");
        let build_dir = output_root.join("build");
        let preview_dir = output_root.join("previews");
        fs::create_dir_all(&build_dir)?;
        fs::create_dir_all(&preview_dir)?;

        let output_bin = build_dir.join("justice-gakuen2-name-entry-form-v3.bin");
        let output_cue = build_dir.join("justice-gakuen2-name-entry-form-v3.cue");
        let report_path = build_dir.join("name-entry-form-v3-report.json");
        let preview_path = preview_dir.join("application-form-english-preview.png");

        let (_, source_stored) =
            crate::disc::rebuild::read_record(input, NAME_ENTRY_FONT_PATH)?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_stored) == SOURCE_STORED_SHA256,
            "MA_ENT.BIZ stored source changed"
        );

        let source_decoded = crate::compression::decompress(&source_stored, true)?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_decoded) == SOURCE_DECODED_SHA256,
            "MA_ENT.BIZ decoded source changed"
        );
        ensure!(
            source_decoded.len() == SOURCE_DECODED_SIZE,
            "MA_ENT.BIZ decoded size changed"
        );

        let tim = crate::tim::parse_4bpp_prefix(&source_decoded)?;
        ensure!(
            tim.image_x == 512
                && tim.image_y == 0
                && tim.pixel_width() == 448
                && tim.image_height == 464
                && tim.clut_width == 16
                && tim.clut_height == 1,
            "application-form TIM geometry changed"
        );

        let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
        let mut patched_decoded = source_decoded.clone();
        let mut patch_report = Vec::new();

        for patch in PATCHES {
            let source_pixels =
                read_indexed_cell_in_prefix(&source_decoded, 0, patch.cell)?;
            let (clear_index, fill_index) = native_clear_and_fill(&source_pixels)?;

            eprintln!(
                "name-entry-form: {} -> {:?} cell=({},{} {}x{}) clear={} fill={}",
                patch.id,
                patch.text,
                patch.cell.x,
                patch.cell.y,
                patch.cell.width,
                patch.cell.height,
                clear_index,
                fill_index
            );

            let rasterized = rasterizer.rasterize(
                patch.text,
                patch.cell.width,
                patch.cell.height,
                patch.font_px,
                patch.tracking_px,
                clear_index,
                None,
                fill_index,
                patch.alignment,
            )?;

            let write = install_indexed_glyph_in_prefix(
                &mut patched_decoded,
                0,
                patch.cell,
                &rasterized.pixels,
                "English enrollment application form",
            )?;
            ensure!(
                write.changed_decoded_byte_count > 0,
                "application-form patch {} changed no bytes",
                patch.id
            );

            patch_report.push(serde_json::json!({
                "id": patch.id,
                "text": patch.text,
                "x": patch.cell.x,
                "y": patch.cell.y,
                "width": patch.cell.width,
                "height": patch.cell.height,
                "font_px": patch.font_px,
                "tracking_px": patch.tracking_px,
                "clear_index": clear_index,
                "fill_index": fill_index,
                "measured_advance_px": rasterized.measured_advance_px,
                "changed_decoded_byte_count": write.changed_decoded_byte_count
            }));
        }

        // Write a decoded preview before touching the disc image.
        let preview =
            crate::tim::decode_4bpp_rgba_in_prefix(&patched_decoded, 0, 0)?;
        crate::tim_preview::write_tim_preview(&preview_path, &preview)?;

        let source_profile =
            crate::paged_compression::source_paged_compression_profile(&source_stored)?;
        let reencoded =
            crate::paged_compression::compress_page_safe_image(&patched_decoded, source_profile)?;
        ensure!(
            crate::compression::decompress(&reencoded, false)? == patched_decoded,
            "MA_ENT page-safe compression roundtrip changed decoded data"
        );
        ensure!(
            reencoded.len() <= source_stored.len(),
            "English application form exceeds fixed MA_ENT.BIZ record"
        );
        let unpadded_size = reencoded.len();

        let mut patched_stored = reencoded;
        patched_stored.resize(source_stored.len(), 0);
        ensure!(
            crate::compression::decompress(&patched_stored, true)? == patched_decoded,
            "padded English MA_ENT.BIZ changed decoded data"
        );

        let replacements = [crate::disc::rebuild::FixedRecordReplacement {
            path: NAME_ENTRY_FONT_PATH,
            data: &patched_stored,
        }];
        let rebuilt =
            crate::disc::rebuild::copy_and_replace_records(input, &output_bin, &replacements)?;
        ensure!(rebuilt.len() == 1, "disc rebuild replaced more than MA_ENT.BIZ");

        let (_, readback) =
            crate::disc::rebuild::read_record(&output_bin, NAME_ENTRY_FONT_PATH)?;
        ensure!(readback == patched_stored, "MA_ENT.BIZ readback differs");
        ensure!(
            crate::compression::decompress(&readback, true)? == patched_decoded,
            "MA_ENT.BIZ decoded readback differs"
        );
        ensure!(
            fs::metadata(input)?.len() == fs::metadata(&output_bin)?.len(),
            "disc image length changed"
        );

        let (changed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(input, &output_bin)?;
        ensure!(!changed_lbas.is_empty(), "English form changed no sectors");
        ensure!(
            changed_lbas.iter().all(|lba| {
                rebuilt.iter().any(|record| record.target_lbas.contains(lba))
            }),
            "English form changed sectors outside MA_ENT.BIZ"
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

        let report = serde_json::json!({
            "kind": "Justice Gakuen 2 English enrollment application form v3",
            "input_bin_sha256": INPUT_SHA256,
            "output_bin_sha256": output_sha256,
            "changed_sector_count": changed_lbas.len(),
            "ma_ent_source_stored_sha256": SOURCE_STORED_SHA256,
            "ma_ent_source_decoded_sha256": SOURCE_DECODED_SHA256,
            "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
            "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
            "ma_ent_unpadded_size": unpadded_size,
            "patches": patch_report,
            "keyboard_grid_untouched": true,
            "mgent_untouched": true,
            "preview": preview_path.display().to_string(),
            "cue": output_cue.display().to_string(),
            "readback_verified": true
        });

        let mut report_bytes = serde_json::to_vec_pretty(&report)?;
        report_bytes.push(b'\n');
        fs::write(&report_path, report_bytes)?;

        eprintln!("NAME_ENTRY_FORM_V3_COMPLETE=1");
        eprintln!("OUTPUT_SHA256={output_sha256}");
        eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
        eprintln!("PREVIEW={}", preview_path.display());
        eprintln!("CUE={}", output_cue.display());

        Ok(())
    }
}

"@

try {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "[1/2] Building direct English application-form patch..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_name_entry_form_v3",
            "--", "--nocapture"
        )
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path $OutputBin)) { Fail "Output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "Output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "Build report missing." }
if (-not (Test-Path $PreviewPng)) { Fail "English form preview missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NAME ENTRY FORM ENGLISH v3 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "PREVIEW TO CHECK FIRST:" -ForegroundColor Yellow
Write-Host $PreviewPng
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "This pass changes only the application-form TIM inside MA_ENT.BIZ." -ForegroundColor Green
Write-Host "MGENT.BIN and the 0-9/A-Z/a-z keyboard grid remain untouched." -ForegroundColor Green

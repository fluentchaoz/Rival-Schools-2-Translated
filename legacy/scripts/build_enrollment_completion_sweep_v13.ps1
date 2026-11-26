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
$RustPath = Join-Path $Upstream "src\dialogue_audit\name_entry_input_tests.rs"

$MasterBin = Join-Path $Upstream "work\english-name-entry-favorite-words-v12\build\justice-gakuen2-name-entry-favorite-words-v12.bin"
$ExpectedMasterHash = "bcc411d59f5f6a45f6aa8e0c20869ef1d4c4e3f22705f17fc66630b45a7da74b"

$WorkRoot = Join-Path $Upstream "work\english-enrollment-completion-sweep-v13"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-enrollment-completion-sweep-v13.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-enrollment-completion-sweep-v13.cue"
$ReportJson = Join-Path $BuildDir "enrollment-completion-sweep-v13-report.json"
$PreviewPng = Join-Path $PreviewDir "enrollment-completion-sweep-v13.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - ENROLLMENT COMPLETION SWEEP v13" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing live-tested v12 BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v12 input BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v12 input hash mismatch. Nothing was changed."
}
Write-Host "v12 input verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_ENROLLMENT_COMPLETION_SWEEP_V13"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v13 sweep injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")
$PreviewLiteral = $PreviewPng.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_ENROLLMENT_COMPLETION_SWEEP_V13
#[test]
fn english_project_enrollment_completion_sweep_v13() -> anyhow::Result<()> {
    use anyhow::{Context, Result, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::tim::{
        Cell, cells_overlap, install_indexed_glyph_in_prefix, read_indexed_cell_in_prefix,
    };

    const INPUT: &str = "$MasterLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";
    const PREVIEW: &str = "$PreviewLiteral";

    const INPUT_SHA256: &str =
        "bcc411d59f5f6a45f6aa8e0c20869ef1d4c4e3f22705f17fc66630b45a7da74b";

    const MA_ENT_PATH: &str = "DAT2/MA_ENT.BIZ";
    const MA_ENT_SOURCE_STORED_SHA256: &str =
        "87d6e17a211eded72e3f3941c725e8b991ad4c5cfe42bc3499933a5d9760d540";

    const FONT_TIM_OFFSET: usize = 0x19_000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    #[derive(Clone, Copy)]
    struct FixedTextPatch {
        id: &'static str,
        text: &'static str,
        cell: Cell,
        start_font_px: f32,
        min_font_px: f32,
        tracking: f32,
        alignment: HorizontalTextAlignment,
    }

    // These are the remaining enrollment/application fixed-text slots visible
    // in the proven v12 MA_ENT atlas.
    //
    // Favorite-word instruction is natively split across two page-14 slots:
    //   main: x=512 y=180 240x20
    //   tail: x=512 y=200  48x20
    // They render together as one instruction in-game.
    //
    // Final confirmation UI:
    //   question: x=512 y=140 240x20
    //   submit:   x=572 y=160  80x20
    //   redo:     x=652 y=160  80x20
    const PATCHES: &[FixedTextPatch] = &[
        FixedTextPatch {
            id: "confirmation-question",
            text: "IS EVERYTHING CORRECT?",
            cell: Cell { x: 512, y: 140, width: 240, height: 20 },
            start_font_px: 14.0,
            min_font_px: 9.0,
            tracking: -0.05,
            alignment: HorizontalTextAlignment::Center,
        },
        FixedTextPatch {
            id: "confirmation-submit",
            text: "SUBMIT",
            cell: Cell { x: 572, y: 160, width: 80, height: 20 },
            start_font_px: 14.0,
            min_font_px: 9.0,
            tracking: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        FixedTextPatch {
            id: "confirmation-redo",
            text: "REDO",
            cell: Cell { x: 652, y: 160, width: 80, height: 20 },
            start_font_px: 14.0,
            min_font_px: 9.0,
            tracking: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        FixedTextPatch {
            id: "favorite-instruction-main",
            text: "CHOOSE 3 FAVORITE",
            cell: Cell { x: 512, y: 180, width: 240, height: 20 },
            start_font_px: 14.0,
            min_font_px: 9.0,
            tracking: -0.05,
            alignment: HorizontalTextAlignment::Left,
        },
        FixedTextPatch {
            id: "favorite-instruction-tail",
            text: "WORDS",
            cell: Cell { x: 512, y: 200, width: 48, height: 20 },
            start_font_px: 12.5,
            min_font_px: 7.0,
            tracking: -0.2,
            alignment: HorizontalTextAlignment::Left,
        },
    ];

    // Already translated/owned neighboring v12 cells. The sweep must not
    // overlap any of these.
    const PROTECTED_CELLS: &[Cell] = &[
        // HIRA / KATA / A-Z
        Cell { x: 560, y: 200, width: 48, height: 24 },
        Cell { x: 608, y: 200, width: 48, height: 24 },
        Cell { x: 656, y: 200, width: 48, height: 24 },
        // DEL / NEXT / BACK / OK
        Cell { x: 512, y: 224, width: 48, height: 24 },
        Cell { x: 560, y: 224, width: 48, height: 24 },
        Cell { x: 608, y: 224, width: 48, height: 24 },
        Cell { x: 656, y: 224, width: 48, height: 24 },
        // Favorite-word choice cells on page 14 row y=120.
        Cell { x: 512, y: 120, width: 60, height: 20 },
        Cell { x: 572, y: 120, width: 60, height: 20 },
        Cell { x: 632, y: 120, width: 60, height: 20 },
        Cell { x: 692, y: 120, width: 60, height: 20 },
    ];

    fn native_indices(pixels: &[u8]) -> Result<(u8, Option<u8>, u8)> {
        let mut counts = [0usize; 16];
        for &p in pixels {
            ensure!(p < 16, "fixed enrollment pixel exceeds 4bpp range");
            counts[usize::from(p)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("fixed enrollment cell is empty")?;

        // Prefer the two most common non-clear ink indexes. Runtime palette
        // selection supplies the final on-screen colors; preserving indexes is
        // what matters here.
        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "fixed enrollment cell contains no ink");

        if inks.len() == 1 {
            Ok((clear, None, inks[0]))
        } else {
            Ok((clear, Some(inks[1]), inks[0]))
        }
    }

    fn rasterize_fitted(
        rasterizer: &IndexedTextRasterizer,
        patch: FixedTextPatch,
        clear: u8,
        outline: Option<u8>,
        fill: u8,
    ) -> Result<(crate::font::RasterizedIndexedText, f32)> {
        let mut font_px = patch.start_font_px;
        loop {
            match rasterizer.rasterize(
                patch.text,
                patch.cell.width,
                patch.cell.height,
                font_px,
                patch.tracking,
                clear,
                outline,
                fill,
                patch.alignment,
            ) {
                Ok(rendered) => return Ok((rendered, font_px)),
                Err(error) => {
                    let message = error.to_string();
                    if message.contains(" needs ")
                        && message.contains(" owns ")
                        && font_px > patch.min_font_px
                    {
                        font_px -= 0.5;
                        continue;
                    }
                    return Err(error);
                }
            }
        }
    }

    let input = Path::new(INPUT);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let report_path = Path::new(REPORT);
    let preview_path = Path::new(PREVIEW);

    ensure!(input.is_file(), "v12 input BIN missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v12 input SHA changed"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;
    fs::create_dir_all(preview_path.parent().context("preview has no parent")?)?;

    let (_, source_stored) = crate::disc::rebuild::read_record(input, MA_ENT_PATH)?;
    ensure!(
        crate::pipeline::sha256_bytes(&source_stored) == MA_ENT_SOURCE_STORED_SHA256,
        "MA_ENT.BIZ v12 source identity changed"
    );

    let source_decoded = crate::compression::decompress(&source_stored, true)?;

    let control_tim = crate::tim::parse_4bpp_prefix(
        source_decoded
            .get(FONT_TIM_OFFSET..)
            .context("name-entry font/control TIM is truncated")?,
    )?;
    ensure!(
        control_tim.image_x == 768
            && control_tim.image_y == 0
            && control_tim.pixel_width() == 768
            && control_tim.image_height == 256
            && control_tim.clut_width == 352
            && control_tim.clut_height == 1,
        "name-entry font/control TIM geometry changed"
    );

    // Prove the five sweep cells are mutually disjoint and avoid all
    // previously translated protected cells.
    for (i, a) in PATCHES.iter().enumerate() {
        for b in PATCHES.iter().skip(i + 1) {
            ensure!(
                !cells_overlap(a.cell, b.cell),
                "v13 sweep cells overlap: {} and {}",
                a.id,
                b.id
            );
        }
        for protected in PROTECTED_CELLS {
            ensure!(
                !cells_overlap(a.cell, *protected),
                "v13 sweep cell {} overlaps a protected translated cell",
                a.id
            );
        }
    }

    let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
    let mut patched_decoded = source_decoded.clone();
    let mut patch_report = Vec::new();

    for &patch in PATCHES {
        let source_pixels =
            read_indexed_cell_in_prefix(&source_decoded, FONT_TIM_OFFSET, patch.cell)?;
        let source_cell_sha = crate::pipeline::sha256_bytes(&source_pixels);
        let nonzero = source_pixels.iter().filter(|&&p| p != 0).count();
        ensure!(
            nonzero > 0,
            "v13 source cell {} contains no visible source pixels",
            patch.id
        );

        let (clear, outline, fill) = native_indices(&source_pixels)?;
        let (rendered, fitted_font_px) =
            rasterize_fitted(&rasterizer, patch, clear, outline, fill)?;

        eprintln!(
            "enrollment-sweep {} -> {:?} cell=({},{} {}x{}) clear={} outline={:?} fill={} font={:.1} source_sha={}",
            patch.id,
            patch.text,
            patch.cell.x,
            patch.cell.y,
            patch.cell.width,
            patch.cell.height,
            clear,
            outline,
            fill,
            fitted_font_px,
            source_cell_sha
        );

        let write = install_indexed_glyph_in_prefix(
            &mut patched_decoded,
            FONT_TIM_OFFSET,
            patch.cell,
            &rendered.pixels,
            "English enrollment completion sweep",
        )?;
        ensure!(
            write.changed_decoded_byte_count > 0,
            "v13 patch {} changed no decoded bytes",
            patch.id
        );

        patch_report.push(json!({
            "id": patch.id,
            "text": patch.text,
            "x": patch.cell.x,
            "y": patch.cell.y,
            "width": patch.cell.width,
            "height": patch.cell.height,
            "source_cell_sha256": source_cell_sha,
            "source_nonzero_pixels": nonzero,
            "clear_index": clear,
            "outline_index": outline,
            "fill_index": fill,
            "fitted_font_px": fitted_font_px,
            "changed_decoded_byte_count": write.changed_decoded_byte_count,
        }));
    }

    // Palette 12 is useful for a structural preview even though some of these
    // fixed sprites are recolored by other runtime palettes in-game.
    let preview =
        crate::tim::decode_4bpp_rgba_in_prefix(&patched_decoded, FONT_TIM_OFFSET, 12)?;
    crate::tim_preview::write_tim_preview(preview_path, &preview)?;

    let source_profile =
        crate::paged_compression::source_paged_compression_profile(&source_stored)?;
    let reencoded =
        crate::paged_compression::compress_page_safe_image(&patched_decoded, source_profile)?;
    ensure!(
        crate::compression::decompress(&reencoded, false)? == patched_decoded,
        "MA_ENT compression roundtrip changed decoded data"
    );
    ensure!(
        reencoded.len() <= source_stored.len(),
        "v13 English enrollment sweep exceeds fixed MA_ENT.BIZ record"
    );

    let unpadded_size = reencoded.len();
    let mut patched_stored = reencoded;
    patched_stored.resize(source_stored.len(), 0);

    ensure!(
        crate::compression::decompress(&patched_stored, true)? == patched_decoded,
        "padded v13 MA_ENT.BIZ changed decoded data"
    );

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: MA_ENT_PATH,
        data: &patched_stored,
    }];

    let rebuilt =
        crate::disc::rebuild::copy_and_replace_records(input, output_bin, &replacements)?;
    ensure!(rebuilt.len() == 1, "v13 replaced more than MA_ENT.BIZ");

    let (_, readback) = crate::disc::rebuild::read_record(output_bin, MA_ENT_PATH)?;
    ensure!(readback == patched_stored, "v13 MA_ENT.BIZ readback differs");
    ensure!(
        crate::compression::decompress(&readback, true)? == patched_decoded,
        "v13 MA_ENT.BIZ decoded readback differs"
    );
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "v13 disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v13 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v13 changed sectors outside MA_ENT.BIZ"
    );

    let bin_name = output_bin
        .file_name()
        .context("v13 output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 enrollment completion sweep v13",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "ma_ent_source_stored_sha256": MA_ENT_SOURCE_STORED_SHA256,
        "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "ma_ent_unpadded_compressed_size": unpadded_size,
        "ma_ent_fixed_record_size": patched_stored.len(),
        "patches": patch_report,
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "mgent_untouched": true,
        "mgk04_untouched": true,
        "v12_choice_tables_preserved": true,
        "readback_verified": true,
        "disc_length_preserved": true,
        "preview": preview_path.display().to_string(),
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("ENROLLMENT_COMPLETION_SWEEP_V13_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("MA_ENT_PATCHED_STORED_SHA256={}", crate::pipeline::sha256_bytes(&patched_stored));
    eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
    eprintln!("PREVIEW={}", preview_path.display());
    eprintln!("CUE={}", output_cue.display());

    Ok(())
}

"@

try {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "[1/2] Building bulk enrollment completion graphics..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_enrollment_completion_sweep_v13",
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

if (-not (Test-Path $OutputBin)) { Fail "v13 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v13 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v13 report JSON missing." }
if (-not (Test-Path $PreviewPng)) { Fail "v13 preview PNG missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "ENROLLMENT COMPLETION SWEEP v13 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "PREVIEW:" -ForegroundColor Yellow
Write-Host $PreviewPng
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "This ONE build attempts all remaining observed enrollment fixed text:" -ForegroundColor Cyan
Write-Host "  CHOOSE 3 FAVORITE WORDS"
Write-Host "  IS EVERYTHING CORRECT?"
Write-Host "  SUBMIT"
Write-Host "  REDO"
Write-Host ""
Write-Host "v12 school/sex/subject/favorite choices remain untouched." -ForegroundColor Green
Write-Host "Check the preview first, then one enrollment playthrough should validate the whole sweep." -ForegroundColor Yellow

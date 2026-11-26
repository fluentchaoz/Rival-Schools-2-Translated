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

$MasterBin = Join-Path $Upstream "work\english-enrollment-completion-sweep-v13\build\justice-gakuen2-enrollment-completion-sweep-v13.bin"
$ExpectedMasterHash = "5010cd27250d4a78651f4e481cb8cb648806fbc3e174f83e219e0c48ecb959f2"

$WorkRoot = Join-Path $Upstream "work\english-face-customization-sweep-v14"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-face-customization-sweep-v14.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-face-customization-sweep-v14.cue"
$ReportJson = Join-Path $BuildDir "face-customization-sweep-v14-report.json"
$PreviewLabels = Join-Path $PreviewDir "face-customization-labels-palette12-v14.png"
$PreviewPrompt = Join-Path $PreviewDir "face-customization-prompt-palette8-v14.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - FACE CUSTOMIZATION SWEEP v14" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing live-tested v13 BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v13 input BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v13 input hash mismatch. Nothing was changed."
}
Write-Host "v13 input verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_FACE_CUSTOMIZATION_SWEEP_V14"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v14 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")
$PreviewLabelsLiteral = $PreviewLabels.Replace("\", "\\")
$PreviewPromptLiteral = $PreviewPrompt.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_FACE_CUSTOMIZATION_SWEEP_V14
#[test]
fn english_project_face_customization_sweep_v14() -> anyhow::Result<()> {
    use anyhow::{Context, Result, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::tim::{Cell, install_indexed_glyph_in_prefix, read_indexed_cell_in_prefix};

    const INPUT: &str = "$MasterLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";
    const PREVIEW_LABELS: &str = "$PreviewLabelsLiteral";
    const PREVIEW_PROMPT: &str = "$PreviewPromptLiteral";

    const INPUT_SHA256: &str =
        "5010cd27250d4a78651f4e481cb8cb648806fbc3e174f83e219e0c48ecb959f2";

    const MGENT_PATH: &str = "DAT1/MGENT.BIN";
    const MA_ENT_PATH: &str = "DAT2/MA_ENT.BIZ";
    const MA_ENT_SOURCE_STORED_SHA256: &str =
        "eb2dbc1610f38e0cc237f64060f2378f29daac2c8adf9ab7c35ac3f95f99bd6a";

    const FONT_TIM_OFFSET: usize = 0x19_000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    // Proven upstream face-feature descriptor table at MGENT +0x0118.
    // Native rows: screen x/y, texture page, u/v, width, palette. Height=20.
    const DESCRIPTOR_OFFSET: usize = 0x0118;
    const DESCRIPTORS: [[u16; 7]; 5] = [
        [74, 166, 12, 220, 160, 20, 12], // eyes
        [74, 196, 12, 180, 180, 20, 12], // nose
        [74, 226, 12, 200, 180, 20, 12], // mouth
        [74, 276, 14, 144, 224, 48, 17], // existing OK; protected
        [74, 316, 14, 40, 100, 160, 8],  // face type: SELECT
    ];

    #[derive(Clone, Copy)]
    struct Patch {
        id: &'static str,
        text: &'static str,
        cell: Cell,
        start_font_px: f32,
        min_font_px: f32,
        tracking: f32,
        alignment: HorizontalTextAlignment,
    }

    // Native Japanese labels are single-character 20x20 cells (目/鼻/口).
    // Keep the same compact visual grammar with one-letter English labels:
    // E = Eyes, N = Nose, M = Mouth.
    const PATCHES: &[Patch] = &[
        Patch {
            id: "eyes",
            text: "E",
            cell: Cell { x: 220, y: 160, width: 20, height: 20 },
            start_font_px: 14.0,
            min_font_px: 10.0,
            tracking: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "nose",
            text: "N",
            cell: Cell { x: 180, y: 180, width: 20, height: 20 },
            start_font_px: 14.0,
            min_font_px: 10.0,
            tracking: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "mouth",
            text: "M",
            cell: Cell { x: 200, y: 180, width: 20, height: 20 },
            start_font_px: 14.0,
            min_font_px: 10.0,
            tracking: 0.0,
            alignment: HorizontalTextAlignment::Center,
        },
        Patch {
            id: "face-type-select",
            text: "FACE TYPE: SELECT",
            cell: Cell { x: 552, y: 100, width: 160, height: 20 },
            start_font_px: 13.0,
            min_font_px: 8.0,
            tracking: -0.1,
            alignment: HorizontalTextAlignment::Left,
        },
    ];

    const PROTECTED_OK: Cell = Cell { x: 656, y: 224, width: 48, height: 24 };

    fn native_indices(pixels: &[u8]) -> Result<(u8, Option<u8>, u8)> {
        let mut counts = [0usize; 16];
        for &p in pixels {
            ensure!(p < 16, "face-customization pixel exceeds 4bpp range");
            counts[usize::from(p)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("face-customization cell is empty")?;

        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "face-customization cell contains no ink");

        if inks.len() == 1 {
            Ok((clear, None, inks[0]))
        } else {
            Ok((clear, Some(inks[1]), inks[0]))
        }
    }

    fn rasterize_fitted(
        rasterizer: &IndexedTextRasterizer,
        patch: Patch,
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

    ensure!(input.is_file(), "v13 input BIN missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v13 input SHA changed"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;
    fs::create_dir_all(
        Path::new(PREVIEW_LABELS)
            .parent()
            .context("preview path has no parent")?,
    )?;

    let (_, mgent) = crate::disc::rebuild::read_record(input, MGENT_PATH)?;

    // Verify the exact native consumer table before touching atlas cells.
    for (index, expected) in DESCRIPTORS.iter().flatten().enumerate() {
        let at = DESCRIPTOR_OFFSET + index * 2;
        let actual = u16::from_le_bytes(
            mgent.get(at..at + 2)
                .context("face-feature descriptor table truncated")?
                .try_into()?,
        );
        ensure!(
            actual == *expected,
            "face-feature descriptor changed at word {index}: expected {expected}, found {actual}"
        );
    }

    let (_, source_stored) = crate::disc::rebuild::read_record(input, MA_ENT_PATH)?;
    ensure!(
        crate::pipeline::sha256_bytes(&source_stored) == MA_ENT_SOURCE_STORED_SHA256,
        "MA_ENT.BIZ v13 source identity changed"
    );

    let source_decoded = crate::compression::decompress(&source_stored, true)?;
    let tim = crate::tim::parse_4bpp_prefix(
        source_decoded
            .get(FONT_TIM_OFFSET..)
            .context("name-entry atlas TIM truncated")?,
    )?;
    ensure!(
        tim.image_x == 768
            && tim.image_y == 0
            && tim.pixel_width() == 768
            && tim.image_height == 256
            && tim.clut_width == 352
            && tim.clut_height == 1,
        "name-entry atlas geometry changed"
    );

    // Prove none of our face text patches touch the existing OK sprite.
    for patch in PATCHES {
        ensure!(
            !crate::tim::cells_overlap(patch.cell, PROTECTED_OK),
            "face patch {} overlaps protected OK sprite",
            patch.id
        );
    }

    let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
    let mut patched_decoded = source_decoded.clone();
    let mut patch_report = Vec::new();

    for &patch in PATCHES {
        let source_pixels =
            read_indexed_cell_in_prefix(&source_decoded, FONT_TIM_OFFSET, patch.cell)?;
        let source_sha = crate::pipeline::sha256_bytes(&source_pixels);
        let nonzero = source_pixels.iter().filter(|&&p| p != 0).count();
        ensure!(nonzero > 0, "source cell {} contains no visible pixels", patch.id);

        let (clear, outline, fill) = native_indices(&source_pixels)?;
        let (rendered, font_px) =
            rasterize_fitted(&rasterizer, patch, clear, outline, fill)?;

        eprintln!(
            "face-sweep {} -> {:?} cell=({},{} {}x{}) clear={} outline={:?} fill={} font={:.1} sha={}",
            patch.id,
            patch.text,
            patch.cell.x,
            patch.cell.y,
            patch.cell.width,
            patch.cell.height,
            clear,
            outline,
            fill,
            font_px,
            source_sha
        );

        let write = install_indexed_glyph_in_prefix(
            &mut patched_decoded,
            FONT_TIM_OFFSET,
            patch.cell,
            &rendered.pixels,
            "English face-customization sweep",
        )?;
        ensure!(
            write.changed_decoded_byte_count > 0,
            "face patch {} changed no decoded bytes",
            patch.id
        );

        patch_report.push(json!({
            "id": patch.id,
            "text": patch.text,
            "x": patch.cell.x,
            "y": patch.cell.y,
            "width": patch.cell.width,
            "height": patch.cell.height,
            "source_cell_sha256": source_sha,
            "source_nonzero_pixels": nonzero,
            "clear_index": clear,
            "outline_index": outline,
            "fill_index": fill,
            "fitted_font_px": font_px,
            "changed_decoded_byte_count": write.changed_decoded_byte_count,
        }));
    }

    // Two previews because the labels and the face-type prompt are consumed
    // with different native palettes (12 and 8).
    let labels_preview =
        crate::tim::decode_4bpp_rgba_in_prefix(&patched_decoded, FONT_TIM_OFFSET, 12)?;
    crate::tim_preview::write_tim_preview(Path::new(PREVIEW_LABELS), &labels_preview)?;

    let prompt_preview =
        crate::tim::decode_4bpp_rgba_in_prefix(&patched_decoded, FONT_TIM_OFFSET, 8)?;
    crate::tim_preview::write_tim_preview(Path::new(PREVIEW_PROMPT), &prompt_preview)?;

    let profile =
        crate::paged_compression::source_paged_compression_profile(&source_stored)?;
    let reencoded =
        crate::paged_compression::compress_page_safe_image(&patched_decoded, profile)?;
    ensure!(
        crate::compression::decompress(&reencoded, false)? == patched_decoded,
        "face-sweep compression roundtrip changed decoded data"
    );
    ensure!(
        reencoded.len() <= source_stored.len(),
        "face-sweep MA_ENT.BIZ exceeds fixed record size"
    );

    let unpadded_size = reencoded.len();
    let mut patched_stored = reencoded;
    patched_stored.resize(source_stored.len(), 0);

    ensure!(
        crate::compression::decompress(&patched_stored, true)? == patched_decoded,
        "face-sweep padded MA_ENT.BIZ changed decoded data"
    );

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: MA_ENT_PATH,
        data: &patched_stored,
    }];
    let rebuilt =
        crate::disc::rebuild::copy_and_replace_records(input, output_bin, &replacements)?;
    ensure!(rebuilt.len() == 1, "face-sweep replaced more than MA_ENT.BIZ");

    let (_, readback) = crate::disc::rebuild::read_record(output_bin, MA_ENT_PATH)?;
    ensure!(readback == patched_stored, "face-sweep MA_ENT.BIZ readback differs");
    ensure!(
        crate::compression::decompress(&readback, true)? == patched_decoded,
        "face-sweep decoded readback differs"
    );
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "face-sweep disc length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v14 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v14 changed sectors outside MA_ENT.BIZ"
    );

    let bin_name = output_bin
        .file_name()
        .context("v14 output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 face customization sweep v14",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "ma_ent_source_stored_sha256": MA_ENT_SOURCE_STORED_SHA256,
        "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "ma_ent_unpadded_compressed_size": unpadded_size,
        "ma_ent_fixed_record_size": patched_stored.len(),
        "patches": patch_report,
        "protected_ok_untouched": true,
        "mgent_descriptor_table_verified": true,
        "mgent_untouched": true,
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "readback_verified": true,
        "disc_length_preserved": true,
        "preview_labels": PREVIEW_LABELS,
        "preview_prompt": PREVIEW_PROMPT,
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("FACE_CUSTOMIZATION_SWEEP_V14_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("MA_ENT_PATCHED_STORED_SHA256={}", crate::pipeline::sha256_bytes(&patched_stored));
    eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
    eprintln!("PREVIEW_LABELS={PREVIEW_LABELS}");
    eprintln!("PREVIEW_PROMPT={PREVIEW_PROMPT}");
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
    Write-Host "[1/2] Building bulk face-customization graphics..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_face_customization_sweep_v14",
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

if (-not (Test-Path $OutputBin)) { Fail "v14 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v14 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v14 report JSON missing." }
if (-not (Test-Path $PreviewLabels)) { Fail "v14 labels preview missing." }
if (-not (Test-Path $PreviewPrompt)) { Fail "v14 prompt preview missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "FACE CUSTOMIZATION SWEEP v14 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "PATCHED IN ONE PASS:" -ForegroundColor Cyan
Write-Host "  E   (Eyes)"
Write-Host "  N   (Nose)"
Write-Host "  M   (Mouth)"
Write-Host "  FACE TYPE: SELECT"
Write-Host ""
Write-Host "Existing OK sprite is protected and unchanged." -ForegroundColor Green
Write-Host ""
Write-Host "LABEL PREVIEW:" -ForegroundColor Yellow
Write-Host $PreviewLabels
Write-Host ""
Write-Host "PROMPT PREVIEW:" -ForegroundColor Yellow
Write-Host $PreviewPrompt
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue

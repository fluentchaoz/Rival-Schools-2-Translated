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

$MasterBin = Join-Path $Upstream "work\english-name-entry-sex-choices-v10\build\justice-gakuen2-name-entry-sex-choices-v10.bin"
$ExpectedMasterHash = "16667311e8d4561cc0d5600c59717539d4c07ccd569700c5d2ed6966a557d2d2"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-best-subject-v11"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-best-subject-v11.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-best-subject-v11.cue"
$ReportJson = Join-Path $BuildDir "name-entry-best-subject-v11-report.json"
$PreviewPng = Join-Path $PreviewDir "best-subject-english-preview-v11.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - BEST SUBJECT ENGLISH v11" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing live-tested v10 BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v10 input BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v10 input hash mismatch. Nothing was changed."
}
Write-Host "v10 input verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_BEST_SUBJECT_V11"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v11 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")
$PreviewLiteral = $PreviewPng.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_BEST_SUBJECT_V11
#[test]
fn english_project_best_subject_v11() -> anyhow::Result<()> {
    use anyhow::{Context, Result, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::tim::{
        Cell, install_indexed_glyph_in_prefix, read_indexed_cell_in_prefix,
    };

    const INPUT: &str = "$MasterLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";
    const PREVIEW: &str = "$PreviewLiteral";

    const INPUT_SHA256: &str =
        "16667311e8d4561cc0d5600c59717539d4c07ccd569700c5d2ed6966a557d2d2";

    const MGENT_PATH: &str = "DAT1/MGENT.BIN";
    const MA_ENT_PATH: &str = "DAT2/MA_ENT.BIZ";
    const MA_ENT_SOURCE_STORED_SHA256: &str =
        "3f1f5ee06e03aefcad24495397ac7d10cc7b848818c4e5a7c69421daaf3e411c";

    const SUBJECT_TABLE_OFFSET: usize = 0x1674;
    const SUBJECT_DESCRIPTOR_COUNT: usize = 8;
    const DESCRIPTOR_SIZE: usize = 6;
    const SUBJECT_TABLE_SHA256: &str =
        "55b4a193a4b0225407b92503362f8711b6cf900d0ff2586f01ab03d5aded56f8";

    const FONT_TIM_OFFSET: usize = 0x19_000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    // Logical order confirmed by the live Japanese popup:
    // top row:    英語 / 社会 / 美術 / 数学
    // bottom row: 国語 / 音楽 / 体育 / 理科
    const SUBJECT_NAMES: [&str; 8] = [
        "ENGLISH",
        "SOCIAL",
        "ART",
        "MATH",
        "JAPANESE",
        "MUSIC",
        "P.E.",
        "SCIENCE",
    ];

    #[derive(Clone, Copy, Debug)]
    struct Descriptor {
        texture_page: u8,
        palette: u8,
        cell: Cell,
    }

    fn parse_descriptor(bytes: &[u8]) -> Result<Descriptor> {
        let [page, palette, u, v, width, height]: [u8; 6] = bytes.try_into()?;
        ensure!((0x0c..=0x0e).contains(&page), "unexpected subject texture page");
        ensure!(width > 0 && height > 0, "empty subject descriptor");
        let x = usize::from(page - 0x0c) * 256 + usize::from(u);
        let y = usize::from(v);
        let cell = Cell {
            x,
            y,
            width: usize::from(width),
            height: usize::from(height),
        };
        ensure!(
            cell.x + cell.width <= 768 && cell.y + cell.height <= 256,
            "subject descriptor exceeds atlas"
        );
        Ok(Descriptor {
            texture_page: page,
            palette,
            cell,
        })
    }

    fn native_indices(pixels: &[u8]) -> Result<(u8, Option<u8>, u8)> {
        let mut counts = [0usize; 16];
        for &p in pixels {
            ensure!(p < 16, "subject-choice pixel exceeds 4bpp range");
            counts[usize::from(p)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("subject cell is empty")?;

        if clear != 3 && clear != 13 && counts[3] > 0 && counts[13] > 0 {
            return Ok((clear, Some(3), 13));
        }

        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "subject cell contains no ink");

        if inks.len() == 1 {
            Ok((clear, None, inks[0]))
        } else {
            Ok((clear, Some(inks[1]), inks[0]))
        }
    }

    fn rasterize_fitted(
        rasterizer: &IndexedTextRasterizer,
        text: &str,
        cell: Cell,
        clear: u8,
        outline: Option<u8>,
        fill: u8,
    ) -> Result<(crate::font::RasterizedIndexedText, f32)> {
        let mut font_px = 12.5f32;
        let min_font_px = 6.5f32;

        loop {
            match rasterizer.rasterize(
                text,
                cell.width,
                cell.height,
                font_px,
                -0.15,
                clear,
                outline,
                fill,
                HorizontalTextAlignment::Center,
            ) {
                Ok(rendered) => return Ok((rendered, font_px)),
                Err(error) => {
                    let message = error.to_string();
                    if message.contains(" needs ") && message.contains(" owns ") && font_px > min_font_px {
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

    ensure!(input.is_file(), "v10 input BIN missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v10 input SHA changed"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;
    fs::create_dir_all(preview_path.parent().context("preview has no parent")?)?;

    let (_, mgent) = crate::disc::rebuild::read_record(input, MGENT_PATH)?;
    let table_size = SUBJECT_DESCRIPTOR_COUNT * DESCRIPTOR_SIZE;
    let table = mgent
        .get(SUBJECT_TABLE_OFFSET..SUBJECT_TABLE_OFFSET + table_size)
        .context("subject descriptor table is truncated")?;
    ensure!(
        crate::pipeline::sha256_bytes(table) == SUBJECT_TABLE_SHA256,
        "subject descriptor table changed"
    );

    let descriptors = table
        .as_chunks::<DESCRIPTOR_SIZE>()
        .0
        .iter()
        .map(|raw| parse_descriptor(raw))
        .collect::<Result<Vec<_>>>()?;
    ensure!(descriptors.len() == 8, "subject descriptor count changed");

    // The audited surface is page 13 / palette 12 / 60x20 for all 8 logical choices.
    ensure!(
        descriptors.iter().all(|d| d.texture_page == 13),
        "subject choices moved away from texture page 13"
    );
    ensure!(
        descriptors.iter().all(|d| d.palette == 12),
        "subject-choice palette changed"
    );
    ensure!(
        descriptors.iter().all(|d| d.cell.width == 60 && d.cell.height == 20),
        "subject-choice cell geometry changed"
    );

    let (_, source_stored) = crate::disc::rebuild::read_record(input, MA_ENT_PATH)?;
    ensure!(
        crate::pipeline::sha256_bytes(&source_stored) == MA_ENT_SOURCE_STORED_SHA256,
        "MA_ENT.BIZ source identity changed"
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

    let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
    let mut patched_decoded = source_decoded.clone();
    let mut patch_report = Vec::new();

    for (index, (descriptor, text)) in descriptors.iter().zip(SUBJECT_NAMES).enumerate() {
        let source_pixels =
            read_indexed_cell_in_prefix(&source_decoded, FONT_TIM_OFFSET, descriptor.cell)?;
        let source_cell_sha = crate::pipeline::sha256_bytes(&source_pixels);
        let (clear, outline, fill) = native_indices(&source_pixels)?;

        let (rendered, fitted_font_px) = rasterize_fitted(
            &rasterizer,
            text,
            descriptor.cell,
            clear,
            outline,
            fill,
        )?;

        eprintln!(
            "subject[{index}] -> {:?} cell=({},{} {}x{}) page={} palette={} clear={} outline={:?} fill={} font={:.1}",
            text,
            descriptor.cell.x,
            descriptor.cell.y,
            descriptor.cell.width,
            descriptor.cell.height,
            descriptor.texture_page,
            descriptor.palette,
            clear,
            outline,
            fill,
            fitted_font_px
        );

        let write = install_indexed_glyph_in_prefix(
            &mut patched_decoded,
            FONT_TIM_OFFSET,
            descriptor.cell,
            &rendered.pixels,
            "English best-subject choice",
        )?;
        ensure!(
            write.changed_decoded_byte_count > 0,
            "subject choice {index} changed no bytes"
        );

        patch_report.push(json!({
            "logical_index": index,
            "text": text,
            "texture_page": descriptor.texture_page,
            "palette": descriptor.palette,
            "x": descriptor.cell.x,
            "y": descriptor.cell.y,
            "width": descriptor.cell.width,
            "height": descriptor.cell.height,
            "source_cell_sha256": source_cell_sha,
            "clear_index": clear,
            "outline_index": outline,
            "fill_index": fill,
            "fitted_font_px": fitted_font_px,
            "changed_decoded_byte_count": write.changed_decoded_byte_count,
        }));
    }

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
        "English subject choices exceed fixed MA_ENT.BIZ record"
    );

    let unpadded_size = reencoded.len();
    let mut patched_stored = reencoded;
    patched_stored.resize(source_stored.len(), 0);

    ensure!(
        crate::compression::decompress(&patched_stored, true)? == patched_decoded,
        "padded MA_ENT.BIZ changed decoded data"
    );

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: MA_ENT_PATH,
        data: &patched_stored,
    }];

    let rebuilt =
        crate::disc::rebuild::copy_and_replace_records(input, output_bin, &replacements)?;
    ensure!(rebuilt.len() == 1, "disc rebuild replaced more than MA_ENT.BIZ");

    let (_, readback) = crate::disc::rebuild::read_record(output_bin, MA_ENT_PATH)?;
    ensure!(readback == patched_stored, "MA_ENT.BIZ readback differs");
    ensure!(
        crate::compression::decompress(&readback, true)? == patched_decoded,
        "MA_ENT.BIZ decoded readback differs"
    );
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v11 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v11 changed sectors outside MA_ENT.BIZ"
    );

    let bin_name = output_bin
        .file_name()
        .context("output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 English best-subject choices v11",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "ma_ent_source_stored_sha256": MA_ENT_SOURCE_STORED_SHA256,
        "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "ma_ent_unpadded_compressed_size": unpadded_size,
        "ma_ent_fixed_record_size": patched_stored.len(),
        "subject_descriptor_table_sha256": SUBJECT_TABLE_SHA256,
        "subject_names": SUBJECT_NAMES,
        "subject_patches": patch_report,
        "mgent_untouched": true,
        "mgk04_untouched": true,
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "readback_verified": true,
        "disc_length_preserved": true,
        "preview": preview_path.display().to_string(),
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("BEST_SUBJECT_V11_COMPLETE=1");
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
    Write-Host "[1/2] Building English BEST SUBJECT choices..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_best_subject_v11",
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

if (-not (Test-Path $OutputBin)) { Fail "v11 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v11 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v11 report JSON missing." }
if (-not (Test-Path $PreviewPng)) { Fail "v11 preview PNG missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "BEST SUBJECT ENGLISH v11 COMPLETE" -ForegroundColor Green
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
Write-Host "Expected popup:" -ForegroundColor Cyan
Write-Host "  ENGLISH   SOCIAL   ART      MATH"
Write-Host "  JAPANESE  MUSIC    P.E.     SCIENCE"
Write-Host ""
Write-Host "Selection behavior, MGENT, and MGK04 remain untouched." -ForegroundColor Green
Write-Host "Do NOT promote v11 until the live BEST SUBJECT popup is checked." -ForegroundColor Yellow

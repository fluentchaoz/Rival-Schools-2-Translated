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

$MasterBin = Join-Path $Upstream "work\english-name-entry-nickname-default-az-v7\build\justice-gakuen2-name-entry-nickname-default-az-v7.bin"
$ExpectedMasterHash = "c9eb6cc1c15eb3b65f1aa9e02cee102fbb1bc502483e88950175139720ca48f5"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-school-choices-v8"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-school-choices-v8.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-school-choices-v8.cue"
$ReportJson = Join-Path $BuildDir "name-entry-school-choices-v8-report.json"
$PreviewPng = Join-Path $PreviewDir "school-choices-english-preview-v8.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - SCHOOL CHOICES ENGLISH v8" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing live-tested v7 master BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v7 master hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_SCHOOL_CHOICES_V8"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v8 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")
$PreviewLiteral = $PreviewPng.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_SCHOOL_CHOICES_V8
#[test]
fn english_project_school_choices_v8() -> anyhow::Result<()> {
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
        "c9eb6cc1c15eb3b65f1aa9e02cee102fbb1bc502483e88950175139720ca48f5";

    const MGENT_PATH: &str = "DAT1/MGENT.BIN";
    const MA_ENT_PATH: &str = "DAT2/MA_ENT.BIZ";

    const SCHOOL_TABLE_OFFSET: usize = 0x15f8;
    const SCHOOL_TABLE_SIZE: usize = 10 * 6;
    const SCHOOL_TABLE_SHA256: &str =
        "518096fc383bf7ef932371bf42eca5a4dd1971f22da01b86d59e6b21445adcfe";
    const SCHOOL_TEXT_DESCRIPTOR_INDEXES: [usize; 5] = [1, 3, 5, 7, 9];
    const SCHOOL_NAMES: [&str; 5] = [
        "TAIYO HIGH",
        "GORIN HIGH",
        "PACIFIC HIGH",
        "GEDO HIGH",
        "JUSTICE HIGH",
    ];

    const FONT_TIM_OFFSET: usize = 0x19_000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    #[derive(Clone, Copy, Debug)]
    struct Descriptor {
        texture_page: u8,
        palette: u8,
        cell: Cell,
    }

    fn parse_descriptor(bytes: &[u8]) -> Result<Descriptor> {
        let [page, palette, u, v, width, height]: [u8; 6] = bytes.try_into()?;
        ensure!((0x0c..=0x0e).contains(&page), "unexpected texture page");
        ensure!(width > 0 && height > 0, "empty choice descriptor");
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
            "choice descriptor exceeds atlas"
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
            ensure!(p < 16, "school text pixel exceeds 4bpp range");
            counts[usize::from(p)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("school choice cell is empty")?;

        // Native name-entry atlas generally uses index 3 as outline and 13 as fill.
        // Prefer those when they are present in the original cell so palette behavior
        // remains native.
        if clear != 3 && clear != 13 && counts[3] > 0 && counts[13] > 0 {
            return Ok((clear, Some(3), 13));
        }

        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "school choice cell has no ink");

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
        let mut font_px = 13.0f32;
        let min_font_px = 7.0f32;

        loop {
            match rasterizer.rasterize(
                text,
                cell.width,
                cell.height,
                font_px,
                -0.1,
                clear,
                outline,
                fill,
                HorizontalTextAlignment::Left,
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

    ensure!(input.is_file(), "v7 master BIN missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v7 master SHA changed"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;
    fs::create_dir_all(preview_path.parent().context("preview has no parent")?)?;

    // Read and verify the descriptor table from MGENT.
    let (_, mgent) = crate::disc::rebuild::read_record(input, MGENT_PATH)?;
    let table = mgent
        .get(SCHOOL_TABLE_OFFSET..SCHOOL_TABLE_OFFSET + SCHOOL_TABLE_SIZE)
        .context("school choice descriptor table is truncated")?;
    ensure!(
        crate::pipeline::sha256_bytes(table) == SCHOOL_TABLE_SHA256,
        "school choice descriptor table changed"
    );

    let descriptors = table
        .as_chunks::<6>()
        .0
        .iter()
        .map(|raw| parse_descriptor(raw))
        .collect::<Result<Vec<_>>>()?;

    // Text descriptors are the odd indexes; even indexes are crest/icon descriptors.
    let school_text = SCHOOL_TEXT_DESCRIPTOR_INDEXES
        .iter()
        .map(|&i| descriptors[i])
        .collect::<Vec<_>>();

    ensure!(school_text.len() == 5, "school text descriptor count changed");
    ensure!(
        school_text.iter().all(|d| d.texture_page == 0x0c),
        "school text moved away from native texture page 12"
    );
    ensure!(
        school_text.iter().all(|d| d.palette == 12),
        "school text palette changed"
    );

    // Read current v7 MA_ENT.BIZ. The full v7 input SHA already pins its exact identity.
    let (_, source_stored) = crate::disc::rebuild::read_record(input, MA_ENT_PATH)?;
    let source_stored_sha = crate::pipeline::sha256_bytes(&source_stored);
    let source_decoded = crate::compression::decompress(&source_stored, true)?;
    let source_decoded_sha = crate::pipeline::sha256_bytes(&source_decoded);

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

    for ((descriptor, text), logical_index) in school_text
        .iter()
        .zip(SCHOOL_NAMES)
        .zip(0usize..)
    {
        let source_pixels =
            read_indexed_cell_in_prefix(&source_decoded, FONT_TIM_OFFSET, descriptor.cell)?;
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
            "school-choice[{logical_index}]: {:?} cell=({},{} {}x{}) page={} palette={} clear={} outline={:?} fill={} font={:.1}",
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
            "English school choice text",
        )?;
        ensure!(
            write.changed_decoded_byte_count > 0,
            "school choice {logical_index} changed no bytes"
        );

        patch_report.push(json!({
            "logical_index": logical_index,
            "text": text,
            "descriptor_index": SCHOOL_TEXT_DESCRIPTOR_INDEXES[logical_index],
            "texture_page": descriptor.texture_page,
            "palette": descriptor.palette,
            "x": descriptor.cell.x,
            "y": descriptor.cell.y,
            "width": descriptor.cell.width,
            "height": descriptor.cell.height,
            "clear_index": clear,
            "outline_index": outline,
            "fill_index": fill,
            "fitted_font_px": fitted_font_px,
            "changed_decoded_byte_count": write.changed_decoded_byte_count,
        }));
    }

    // Palette 12 is the native school-choice palette.
    let preview =
        crate::tim::decode_4bpp_rgba_in_prefix(&patched_decoded, FONT_TIM_OFFSET, 12)?;
    crate::tim_preview::write_tim_preview(preview_path, &preview)?;

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
        "English school names exceed fixed MA_ENT.BIZ record"
    );

    let unpadded_size = reencoded.len();
    let mut patched_stored = reencoded;
    patched_stored.resize(source_stored.len(), 0);

    ensure!(
        crate::compression::decompress(&patched_stored, true)? == patched_decoded,
        "padded school-choice MA_ENT.BIZ changed decoded data"
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
    ensure!(!changed_lbas.is_empty(), "v8 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v8 changed sectors outside MA_ENT.BIZ"
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
        "kind": "Justice Gakuen 2 English school choices v8",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "ma_ent_source_stored_sha256": source_stored_sha,
        "ma_ent_source_decoded_sha256": source_decoded_sha,
        "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "ma_ent_unpadded_compressed_size": unpadded_size,
        "ma_ent_fixed_record_size": patched_stored.len(),
        "school_descriptor_table_sha256": SCHOOL_TABLE_SHA256,
        "school_names": SCHOOL_NAMES,
        "school_patches": patch_report,
        "crest_descriptors_untouched": true,
        "mgent_untouched": true,
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

    eprintln!("SCHOOL_CHOICES_V8_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("MA_ENT_SOURCE_STORED_SHA256={source_stored_sha}");
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
    Write-Host "[1/2] Building English school-choice graphics..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_school_choices_v8",
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

if (-not (Test-Path $OutputBin)) { Fail "v8 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v8 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v8 report JSON missing." }
if (-not (Test-Path $PreviewPng)) { Fail "v8 preview PNG missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "SCHOOL CHOICES ENGLISH v8 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "PREVIEW TO CHECK:" -ForegroundColor Yellow
Write-Host $PreviewPng
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "Expected school labels:" -ForegroundColor Cyan
Write-Host "  TAIYO HIGH"
Write-Host "  GORIN HIGH"
Write-Host "  PACIFIC HIGH"
Write-Host "  GEDO HIGH"
Write-Host "  JUSTICE HIGH"
Write-Host ""
Write-Host "Crest icons and MGENT selection logic remain untouched." -ForegroundColor Green
Write-Host "Do NOT promote v8 until preview + live popup are checked." -ForegroundColor Yellow

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

$MasterBin = Join-Path $Upstream "work\english-mgk04-welcome-hybrid-v9b\build\justice-gakuen2-mgk04-welcome-hybrid-v9b.bin"
$ExpectedMasterHash = "403fe83463e714d2621fd404d1556a31021ff2332c5bb9ea5b3d6a59af330371"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-sex-choices-v10"
$BuildDir = Join-Path $WorkRoot "build"
$PreviewDir = Join-Path $WorkRoot "previews"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-sex-choices-v10.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-sex-choices-v10.cue"
$ReportJson = Join-Path $BuildDir "name-entry-sex-choices-v10-report.json"
$PreviewPng = Join-Path $PreviewDir "sex-choices-english-preview-v10.png"

Write-Host ""
Write-Host "Justice Gakuen English Project - SEX CHOICES ENGLISH v10" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing v9b candidate BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v9b input BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v9b input hash mismatch. Nothing was changed."
}
Write-Host "v9b input verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_SEX_CHOICES_V10"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v10 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")
$PreviewLiteral = $PreviewPng.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_SEX_CHOICES_V10
#[test]
fn english_project_sex_choices_v10() -> anyhow::Result<()> {
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
        "403fe83463e714d2621fd404d1556a31021ff2332c5bb9ea5b3d6a59af330371";

    const MA_ENT_PATH: &str = "DAT2/MA_ENT.BIZ";
    const MA_ENT_SOURCE_STORED_SHA256: &str =
        "c2613b06555503a1dbd9e6a720c5650ea2b974d480469e712637496f027f7b5f";

    const FONT_TIM_OFFSET: usize = 0x19_000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    #[derive(Clone, Copy)]
    struct Choice {
        id: &'static str,
        text: &'static str,
        cell: Cell,
    }

    const CHOICES: &[Choice] = &[
        Choice {
            id: "male",
            text: "M",
            cell: Cell { x: 180, y: 140, width: 20, height: 20 },
        },
        Choice {
            id: "female",
            text: "F",
            cell: Cell { x: 200, y: 140, width: 20, height: 20 },
        },
    ];

    fn native_indices(pixels: &[u8]) -> Result<(u8, Option<u8>, u8)> {
        let mut counts = [0usize; 16];
        for &p in pixels {
            ensure!(p < 16, "sex-choice pixel exceeds 4bpp range");
            counts[usize::from(p)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("sex-choice cell is empty")?;

        if clear != 3 && clear != 13 && counts[3] > 0 && counts[13] > 0 {
            return Ok((clear, Some(3), 13));
        }

        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "sex-choice cell contains no ink");

        if inks.len() == 1 {
            Ok((clear, None, inks[0]))
        } else {
            Ok((clear, Some(inks[1]), inks[0]))
        }
    }

    let input = Path::new(INPUT);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let report_path = Path::new(REPORT);
    let preview_path = Path::new(PREVIEW);

    ensure!(input.is_file(), "v9b input BIN missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v9b input SHA changed"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;
    fs::create_dir_all(preview_path.parent().context("preview has no parent")?)?;

    let (_, source_stored) = crate::disc::rebuild::read_record(input, MA_ENT_PATH)?;
    ensure!(
        crate::pipeline::sha256_bytes(&source_stored) == MA_ENT_SOURCE_STORED_SHA256,
        "MA_ENT.BIZ source identity changed"
    );

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

    ensure!(
        CHOICES[0].cell.x + CHOICES[0].cell.width == CHOICES[1].cell.x,
        "sex-choice native cells are no longer adjacent"
    );

    let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
    let mut patched_decoded = source_decoded.clone();
    let mut patch_report = Vec::new();

    for choice in CHOICES {
        let source_pixels =
            read_indexed_cell_in_prefix(&source_decoded, FONT_TIM_OFFSET, choice.cell)?;
        let source_cell_sha = crate::pipeline::sha256_bytes(&source_pixels);
        let (clear, outline, fill) = native_indices(&source_pixels)?;

        let rendered = rasterizer.rasterize(
            choice.text,
            choice.cell.width,
            choice.cell.height,
            14.0,
            0.0,
            clear,
            outline,
            fill,
            HorizontalTextAlignment::Center,
        )?;

        eprintln!(
            "sex-choice {} -> {:?} cell=({},{} {}x{}) clear={} outline={:?} fill={} source_cell_sha={}",
            choice.id,
            choice.text,
            choice.cell.x,
            choice.cell.y,
            choice.cell.width,
            choice.cell.height,
            clear,
            outline,
            fill,
            source_cell_sha
        );

        let write = install_indexed_glyph_in_prefix(
            &mut patched_decoded,
            FONT_TIM_OFFSET,
            choice.cell,
            &rendered.pixels,
            "English sex-choice glyph",
        )?;
        ensure!(
            write.changed_decoded_byte_count > 0,
            "sex choice {} changed no bytes",
            choice.id
        );

        patch_report.push(json!({
            "id": choice.id,
            "text": choice.text,
            "x": choice.cell.x,
            "y": choice.cell.y,
            "width": choice.cell.width,
            "height": choice.cell.height,
            "source_cell_sha256": source_cell_sha,
            "clear_index": clear,
            "outline_index": outline,
            "fill_index": fill,
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
        "English sex choices exceed fixed MA_ENT.BIZ record"
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
    ensure!(!changed_lbas.is_empty(), "v10 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v10 changed sectors outside MA_ENT.BIZ"
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
        "kind": "Justice Gakuen 2 English sex choices v10",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "ma_ent_source_stored_sha256": MA_ENT_SOURCE_STORED_SHA256,
        "ma_ent_source_decoded_sha256": source_decoded_sha,
        "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "ma_ent_unpadded_compressed_size": unpadded_size,
        "ma_ent_fixed_record_size": patched_stored.len(),
        "choices": patch_report,
        "choice_mapping": ["male -> M", "female -> F"],
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

    eprintln!("SEX_CHOICES_V10_COMPLETE=1");
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
    Write-Host "[1/2] Building English M/F sex-choice graphics..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_sex_choices_v10",
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

if (-not (Test-Path $OutputBin)) { Fail "v10 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v10 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v10 report JSON missing." }
if (-not (Test-Path $PreviewPng)) { Fail "v10 preview PNG missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "SEX CHOICES ENGLISH v10 COMPLETE" -ForegroundColor Green
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
Write-Host "  M"
Write-Host "  F"
Write-Host ""
Write-Host "Selection behavior, MGENT, and MGK04 remain untouched." -ForegroundColor Green
Write-Host "Do NOT promote v10 until the live SEX popup is checked." -ForegroundColor Yellow

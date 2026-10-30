[CmdletBinding()]
param(
    [string]$MasterBin = "",
    [string]$SourceBin = "",
    [string]$UpstreamRoot = "",
    [string]$WorkRoot = "",
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    throw $Message
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail ("{0} failed with exit code {1}." -f $Command, $LASTEXITCODE)
    }
}

function Resolve-FullPath([string]$Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

function Assert-FreeSpace([string]$BuildPath, [long]$DiscBytes, [string]$TargetPath) {
    # One rebuilt image plus small reports, and 4 GiB of compilation headroom.
    # Sum budgets when output and Cargo target share a volume.
    $Budgets = @{}
    foreach ($Need in @(
        @{ Path = $BuildPath; Bytes = $DiscBytes + 32MB },
        @{ Path = $TargetPath; Bytes = 4GB }
    )) {
        $Root = [System.IO.Path]::GetPathRoot((Resolve-FullPath $Need.Path))
        if (-not $Budgets.ContainsKey($Root)) { $Budgets[$Root] = [long]0 }
        $Budgets[$Root] += [long]$Need.Bytes
    }
    foreach ($Root in $Budgets.Keys) {
        $Drive = [System.IO.DriveInfo]::new($Root)
        $Required = [long]$Budgets[$Root]
        $Available = [long]$Drive.AvailableFreeSpace
        Write-Host ("Free space on {0}: {1:N2} GiB; required headroom: {2:N2} GiB" -f $Root, ($Available / 1GB), ($Required / 1GB))
        if ($Available -lt $Required) {
            Fail ("Not enough free space on {0}. Free at least {1:N2} GiB or choose -WorkRoot / CARGO_TARGET_DIR on a roomier drive. No output or source file has been changed." -f $Root, (($Required - $Available) / 1GB))
        }
    }
}

$Here = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($UpstreamRoot)) {
    $UpstreamRoot = Join-Path $Here "upstream"
}
$Upstream = Resolve-FullPath $UpstreamRoot
$RustPath = Join-Path $Upstream "src/diary_scene/runtime_bundle_build.rs"
if ([string]::IsNullOrWhiteSpace($MasterBin)) {
    $MasterBin = Join-Path $Upstream "work/english-live-mgk04-quiz-v16/build/justice-gakuen2-live-mgk04-quiz-v16.bin"
}
if ([string]::IsNullOrWhiteSpace($SourceBin)) {
    $SourceBin = Join-Path (Split-Path -Parent $Here) "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
}
if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
    $WorkRoot = Join-Path $Upstream "work/english-quiz-fixed-ui-v17h"
}
$MasterBin = Resolve-FullPath $MasterBin
$SourceBin = Resolve-FullPath $SourceBin
$WorkRoot = Resolve-FullPath $WorkRoot
$ExpectedMasterHash = "67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-quiz-fixed-ui-v17h.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-quiz-fixed-ui-v17h.cue"
$PreviewPng = Join-Path $BuildDir "quiz-fixed-ui-v17h-atlas.png"
$ReportJson = Join-Path $BuildDir "quiz-fixed-ui-v17h-report.json"
$BackupPath = Join-Path $WorkRoot "runtime_bundle_build.pre-v17h.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v17h.log"

Write-Host ""
Write-Host "Justice Gakuen English Project - QUIZ FIXED UI ENGLISH v17h" -ForegroundColor Cyan
foreach ($p in @($RustPath, $MasterBin, $SourceBin)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Fail ("Missing required file: {0}" -f $p)
    }
}
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not on PATH. Open the terminal where the previous translation build worked."
}

$MasterHash = (Get-FileHash -LiteralPath $MasterBin -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("v16 master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v16 master hash mismatch. Nothing was modified."
}
$SourceHash = (Get-FileHash -LiteralPath $SourceBin -Algorithm SHA256).Hash.ToLowerInvariant()
if ($SourceHash -ne $ExpectedSourceHash) {
    Fail "Original source hash mismatch. Nothing was modified."
}

$OriginalRustBytes = [System.IO.File]::ReadAllBytes($RustPath)
$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$OriginalRustHash = (Get-FileHash -LiteralPath $RustPath -Algorithm SHA256).Hash
if ($OriginalRust -match 'ENGLISH_PROJECT_QUIZ_FIXED_UI_V17[GH]') {
    Fail "An earlier quiz UI test is still injected into runtime_bundle_build.rs. Restore its saved source backup before building."
}
foreach ($p in @($OutputBin, $OutputCue, $PreviewPng, $ReportJson, $BackupPath, $LogPath)) {
    if (Test-Path -LiteralPath $p) {
        Fail ("Output already exists: {0}. Keep it and use -WorkRoot with a new folder." -f $p)
    }
}
$TargetPath = Join-Path $Upstream "target"
if (-not [string]::IsNullOrWhiteSpace($env:CARGO_TARGET_DIR)) {
    $TargetPath = $env:CARGO_TARGET_DIR
    if (-not [System.IO.Path]::IsPathRooted($TargetPath)) {
        $TargetPath = Join-Path $Upstream $TargetPath
    }
}
Assert-FreeSpace $BuildDir (Get-Item -LiteralPath $MasterBin).Length $TargetPath
Write-Host "v16 and original source verified. Output paths and free space checked." -ForegroundColor Green
if ($CheckOnly) {
    Write-Host "Preflight passed. No files changed." -ForegroundColor Green
    return
}

function RustLiteral([string]$Value) {
    return $Value.Replace("\", "\\").Replace('"', '\"')
}
$MasterLiteral = RustLiteral $MasterBin
$SourceLiteral = RustLiteral $SourceBin
$OutputBinLiteral = RustLiteral $OutputBin
$OutputCueLiteral = RustLiteral $OutputCue
$PreviewLiteral = RustLiteral $PreviewPng
$ReportLiteral = RustLiteral $ReportJson

$Rust = @"

// ENGLISH_PROJECT_QUIZ_FIXED_UI_V17H
#[test]
fn english_project_quiz_fixed_ui_v17h() -> anyhow::Result<()> {
    use anyhow::{Context, Result, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    use crate::tim::{Cell, read_indexed_cell_in_prefix, write_indexed_cell_in_prefix};

    const MASTER: &str = "$MasterLiteral";
    const SOURCE: &str = "$SourceLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const PREVIEW: &str = "$PreviewLiteral";
    const REPORT: &str = "$ReportLiteral";

    const MASTER_SHA256: &str =
        "67ad4b9d628d0141493a42b456dfd8ce7631d3e9fdd7b2d387ceb84362127a51";
    const SOURCE_SHA256: &str =
        "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";

    const RECORD_PATH: &str = "DAT2/MGBGK04.BZZ";
    const SOURCE_ARCHIVE_SHA256: &str =
        "c45932c3ae22706250f3db1c000d9f8911a475083bd74e485c6daebbb3167558";
    const MEMBER_INDEX: usize = 2;
    const SOURCE_MEMBER_COMPRESSED_SHA256: &str =
        "a11eb95d2a3de960a7f2841e6b2d5028b213edff28841b1b3e2d9d30778d2064";
    const SOURCE_MEMBER_DECODED_SHA256: &str =
        "10ee479ec26217e547a2231b3cc9e9388aac05633f1f5ea54b51c23ca82b924e";
    const TIM_OFFSET: usize = 0xE000;
    const SOURCE_TIM_SHA256: &str =
        "c5c3eead124f69404ea5b9943165f1cf9098af3ff51820bea37e7de4cd00fb59";

    const CORRECT_CELL: Cell = Cell {
        x: 0,
        y: 0,
        width: 180,
        height: 224,
    };
    const WRONG_CELL: Cell = Cell {
        x: 258,
        y: 0,
        width: 190,
        height: 224,
    };
    const QUESTION_CELL: Cell = Cell {
        x: 180,
        y: 164,
        width: 78,
        height: 36,
    };
    const EXAM_OVER_CELL: Cell = Cell {
        x: 508,
        y: 136,
        width: 210,
        height: 64,
    };

    fn glyph_rows(ch: char) -> [u8; 7] {
        match ch {
            'A' => [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
            'C' => [0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110],
            'E' => [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
            'G' => [0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01110],
            'I' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b11111],
            'M' => [0b10001,0b11011,0b10101,0b10101,0b10001,0b10001,0b10001],
            'N' => [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
            'O' => [0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
            'Q' => [0b01110,0b10001,0b10001,0b10001,0b10101,0b10010,0b01101],
            'R' => [0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
            'S' => [0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110],
            'T' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
            'U' => [0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
            'V' => [0b10001,0b10001,0b10001,0b10001,0b10001,0b01010,0b00100],
            'W' => [0b10001,0b10001,0b10001,0b10101,0b10101,0b11011,0b10001],
            'X' => [0b10001,0b01010,0b00100,0b00100,0b00100,0b01010,0b10001],
            '!' => [0b00100,0b00100,0b00100,0b00100,0b00100,0b00000,0b00100],
            ' ' => [0,0,0,0,0,0,0],
            _ => panic!("unsupported bitmap-font character {ch:?}"),
        }
    }

    fn render_text_mask(text: &str, scale_x: usize, scale_y: usize) -> (usize, usize, Vec<u8>) {
        let chars = text.chars().collect::<Vec<_>>();
        let width = chars.len() * 5 * scale_x
            + chars.len().saturating_sub(1) * scale_x;
        let height = 7 * scale_y;
        let mut mask = vec![0u8; width * height];

        for (char_index, ch) in chars.into_iter().enumerate() {
            let rows = glyph_rows(ch);
            let origin_x = char_index * 6 * scale_x;
            for (row, bits) in rows.into_iter().enumerate() {
                for col in 0..5 {
                    if bits & (1 << (4 - col)) == 0 {
                        continue;
                    }
                    for sy in 0..scale_y {
                        for sx in 0..scale_x {
                            let x = origin_x + col * scale_x + sx;
                            let y = row * scale_y + sy;
                            mask[y * width + x] = 1;
                        }
                    }
                }
            }
        }
        (width, height, mask)
    }

    fn draw_text_centered(
        pixels: &mut [u8],
        width: usize,
        height: usize,
        text: &str,
        scale_x: usize,
        scale_y: usize,
        fill_index: u8,
        outline_index: Option<u8>,
    ) -> Result<()> {
        let (text_width, text_height, mask) = render_text_mask(text, scale_x, scale_y);
        ensure!(
            text_width <= width && text_height <= height,
            "text {text:?} does not fit {width}x{height}"
        );
        let x0 = (width - text_width) / 2;
        let y0 = (height - text_height) / 2;

        if let Some(outline) = outline_index {
            for y in 0..text_height {
                for x in 0..text_width {
                    if mask[y * text_width + x] == 0 {
                        continue;
                    }
                    let px = x0 + x;
                    let py = y0 + y;
                    for dy in -1i32..=1 {
                        for dx in -1i32..=1 {
                            let nx = px as i32 + dx;
                            let ny = py as i32 + dy;
                            if nx >= 0 && ny >= 0 && nx < width as i32 && ny < height as i32 {
                                pixels[ny as usize * width + nx as usize] = outline;
                            }
                        }
                    }
                }
            }
        }

        for y in 0..text_height {
            for x in 0..text_width {
                if mask[y * text_width + x] != 0 {
                    pixels[(y0 + y) * width + (x0 + x)] = fill_index;
                }
            }
        }
        Ok(())
    }

    fn draw_stamp_source(
        text: &str,
        scale: usize,
        width: usize,
        height: usize,
    ) -> Result<Vec<u8>> {
        let mut mask = vec![0u8; width * height];
        let border = 3usize;

        for layer in 0..border {
            let left = layer;
            let right = width - 1 - layer;
            let top = layer;
            let bottom = height - 1 - layer;
            for x in left..=right {
                mask[top * width + x] = 1;
                mask[bottom * width + x] = 1;
            }
            for y in top..=bottom {
                mask[y * width + left] = 1;
                mask[y * width + right] = 1;
            }
        }

        let (tw, th, text_mask) = render_text_mask(text, scale, scale);
        ensure!(tw + 10 <= width && th + 10 <= height, "stamp text does not fit");
        let x0 = (width - tw) / 2;
        let y0 = (height - th) / 2;
        for y in 0..th {
            for x in 0..tw {
                if text_mask[y * tw + x] != 0 {
                    mask[(y0 + y) * width + x0 + x] = 1;
                }
            }
        }
        Ok(mask)
    }

    fn rotate_mask_into_cell(
        source: &[u8],
        source_width: usize,
        source_height: usize,
        cell_width: usize,
        cell_height: usize,
        angle_degrees: f32,
        clear_index: u8,
        fill_index: u8,
    ) -> Vec<u8> {
        let mut out = vec![clear_index; cell_width * cell_height];
        let angle = angle_degrees.to_radians();
        let cos = angle.cos();
        let sin = angle.sin();
        let scx = (source_width as f32 - 1.0) / 2.0;
        let scy = (source_height as f32 - 1.0) / 2.0;
        let tcx = (cell_width as f32 - 1.0) / 2.0;
        let tcy = (cell_height as f32 - 1.0) / 2.0;

        for ty in 0..cell_height {
            for tx in 0..cell_width {
                let dx = tx as f32 - tcx;
                let dy = ty as f32 - tcy;

                // Inverse rotation from target pixel to source pixel.
                let sx = cos * dx + sin * dy + scx;
                let sy = -sin * dx + cos * dy + scy;

                let ix = sx.round() as i32;
                let iy = sy.round() as i32;
                if ix >= 0
                    && iy >= 0
                    && ix < source_width as i32
                    && iy < source_height as i32
                    && source[iy as usize * source_width + ix as usize] != 0
                {
                    out[ty * cell_width + tx] = fill_index;
                }
            }
        }
        out
    }

    fn palette_roles(pixels: &[u8]) -> Result<(u8, Vec<u8>)> {
        let mut counts = [0usize; 16];
        for &pixel in pixels {
            ensure!(pixel < 16, "4-bpp pixel escaped palette");
            counts[usize::from(pixel)] += 1;
        }
        let clear = counts
            .iter()
            .enumerate()
            .max_by_key(|(index, count)| (**count, std::cmp::Reverse(*index)))
            .map(|(index, _)| index as u8)
            .context("empty indexed cell")?;

        let mut ink = counts
            .iter()
            .enumerate()
            .filter(|(index, count)| **count > 0 && *index != usize::from(clear))
            .map(|(index, count)| (index as u8, *count))
            .collect::<Vec<_>>();
        ink.sort_by_key(|(index, count)| (std::cmp::Reverse(*count), *index));

        ensure!(!ink.is_empty(), "cell has no non-clear palette index");
        Ok((clear, ink.into_iter().map(|(index, _)| index).collect()))
    }

    fn patch_stamp(
        decoded: &mut [u8],
        source_decoded: &[u8],
        cell: Cell,
        text: &str,
        scale: usize,
        source_width: usize,
        source_height: usize,
    ) -> Result<(u8, u8)> {
        let source_pixels = read_indexed_cell_in_prefix(source_decoded, TIM_OFFSET, cell)?;
        let (clear, ink) = palette_roles(&source_pixels)?;
        let fill = ink[0];

        let source_mask = draw_stamp_source(text, scale, source_width, source_height)?;
        let pixels = rotate_mask_into_cell(
            &source_mask,
            source_width,
            source_height,
            cell.width,
            cell.height,
            15.0,
            clear,
            fill,
        );
        write_indexed_cell_in_prefix(decoded, TIM_OFFSET, cell, &pixels)?;
        Ok((clear, fill))
    }

    fn patch_text(
        decoded: &mut [u8],
        source_decoded: &[u8],
        cell: Cell,
        text: &str,
        scale_x: usize,
        scale_y: usize,
        fill_rank: usize,
        outline_rank: Option<usize>,
    ) -> Result<(u8, u8, Option<u8>)> {
        let source_pixels = read_indexed_cell_in_prefix(source_decoded, TIM_OFFSET, cell)?;
        let (clear, ink) = palette_roles(&source_pixels)?;
        ensure!(fill_rank < ink.len(), "fill palette rank escaped source cell");
        let fill = ink[fill_rank];
        let outline = outline_rank.map(|rank| {
            ensure!(rank < ink.len(), "outline palette rank escaped source cell");
            Ok(ink[rank])
        }).transpose()?;

        let mut pixels = vec![clear; cell.width * cell.height];
        draw_text_centered(
            &mut pixels,
            cell.width,
            cell.height,
            text,
            scale_x,
            scale_y,
            fill,
            outline,
        )?;
        write_indexed_cell_in_prefix(decoded, TIM_OFFSET, cell, &pixels)?;
        Ok((clear, fill, outline))
    }

    let master = Path::new(MASTER);
    let source = Path::new(SOURCE);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let preview = Path::new(PREVIEW);
    let report_path = Path::new(REPORT);

    ensure!(
        crate::pipeline::sha256_file(master)? == MASTER_SHA256,
        "v16 master SHA changed"
    );
    ensure!(
        crate::pipeline::sha256_file(source)? == SOURCE_SHA256,
        "source BIN SHA changed"
    );

    let (_, master_archive) = crate::disc::rebuild::read_record(master, RECORD_PATH)?;
    let (_, source_archive) = crate::disc::rebuild::read_record(source, RECORD_PATH)?;

    ensure!(
        crate::pipeline::sha256_bytes(&source_archive) == SOURCE_ARCHIVE_SHA256,
        "source MGBGK04.BZZ SHA changed"
    );
    let master_members = crate::tzz::parse_tzz(&master_archive)?;
    let source_members = crate::tzz::parse_tzz(&source_archive)?;
    ensure!(
        master_members.len() == 3 && source_members.len() == 3,
        "MGBGK04 member count changed"
    );

    let master_member = master_members[MEMBER_INDEX];
    let source_member = source_members[MEMBER_INDEX];

    // The original disc is source-binding evidence only. Patch the current v16
    // member so prior MGBGK04 work (especially School Gate in member 0) survives.
    let original_compressed = &source_archive[source_member.compressed_range()];
    ensure!(
        crate::pipeline::sha256_bytes(original_compressed) == SOURCE_MEMBER_COMPRESSED_SHA256,
        "original MGBGK04 member 2 compressed SHA changed"
    );
    let original_decoded = crate::compression::decompress(original_compressed, false)?;
    ensure!(
        crate::pipeline::sha256_bytes(&original_decoded) == SOURCE_MEMBER_DECODED_SHA256,
        "original MGBGK04 member 2 decoded SHA changed"
    );
    let original_tim = crate::embedded_tim::parse_embedded_tim_at(&original_decoded, TIM_OFFSET)?;
    ensure!(
        original_tim.source_tim_sha256 == SOURCE_TIM_SHA256,
        "original quiz UI TIM SHA changed"
    );

    let master_compressed = &master_archive[master_member.compressed_range()];
    let master_decoded = crate::compression::decompress(master_compressed, false)?;
    let master_tim = crate::embedded_tim::parse_embedded_tim_at(&master_decoded, TIM_OFFSET)?;
    ensure!(master_tim.bits_per_pixel == 4, "quiz UI TIM is no longer 4-bpp");
    ensure!(
        master_tim.pixel_width == 768 && master_tim.pixel_height == 256,
        "quiz UI TIM geometry changed"
    );
    ensure!(
        master_tim.source_tim_sha256 == SOURCE_TIM_SHA256,
        "v16 already changed the quiz UI TIM; refusing to overwrite it"
    );

    let mut patched_decoded = master_decoded.clone();

    let correct_palette = patch_stamp(
        &mut patched_decoded,
        &master_decoded,
        CORRECT_CELL,
        "CORRECT!",
        3,
        160,
        64,
    )?;
    let wrong_palette = patch_stamp(
        &mut patched_decoded,
        &master_decoded,
        WRONG_CELL,
        "WRONG!",
        4,
        160,
        64,
    )?;
    let question_palette = patch_text(
        &mut patched_decoded,
        &master_decoded,
        QUESTION_CELL,
        "QUESTION",
        1,
        2,
        0,
        Some(1),
    )?;
    let exam_palette = patch_text(
        &mut patched_decoded,
        &master_decoded,
        EXAM_OVER_CELL,
        "EXAM OVER",
        3,
        3,
        1,
        Some(0),
    )?;

    ensure!(patched_decoded != master_decoded, "quiz UI patch made no changes");

    // Verify the four owned cells changed and every indexed pixel outside them is untouched.
    let source_image = crate::tim::read_4bpp_indexed_image_in_prefix(&master_decoded, TIM_OFFSET)?;
    let patched_image = crate::tim::read_4bpp_indexed_image_in_prefix(&patched_decoded, TIM_OFFSET)?;
    ensure!(
        source_image.width == patched_image.width && source_image.height == patched_image.height,
        "patched quiz UI image geometry changed"
    );

    let owned = [CORRECT_CELL, WRONG_CELL, QUESTION_CELL, EXAM_OVER_CELL];
    let mut changed_pixels = 0usize;
    for y in 0..source_image.height {
        for x in 0..source_image.width {
            let index = y * source_image.width + x;
            if source_image.pixels[index] == patched_image.pixels[index] {
                continue;
            }
            changed_pixels += 1;
            ensure!(
                owned.iter().any(|cell| {
                    x >= cell.x
                        && x < cell.x + cell.width
                        && y >= cell.y
                        && y < cell.y + cell.height
                }),
                "quiz UI patch changed pixel outside owned cells at ({x},{y})"
            );
        }
    }
    ensure!(changed_pixels > 0, "quiz UI has zero changed pixels");

    // Preserve the native diary runtime compression contract.
    let encoding = encode_runtime_member(
        master_compressed,
        &master_decoded,
        &patched_decoded,
    )?;
    let reencoded = encoding.bytes;
    ensure!(
        reencoded.len() <= master_member.compressed_size,
        "patched MGBGK04 member 2 exceeds source compressed slot: {} > {}",
        reencoded.len(),
        master_member.compressed_size
    );

    let rebuilt_compressed_size = reencoded.len();
    let mut stored_member = vec![0u8; master_member.compressed_size];
    stored_member[..reencoded.len()].copy_from_slice(&reencoded);

    ensure!(
        crate::compression::decompress(&stored_member, true)? == patched_decoded,
        "padded MGBGK04 member 2 does not decode to patched bytes"
    );

    let mut patched_archive = master_archive.clone();
    patched_archive[master_member.compressed_range()].copy_from_slice(&stored_member);
    ensure!(
        patched_archive.len() == master_archive.len(),
        "MGBGK04 archive length changed"
    );

    // Reparse unchanged TZZ geometry after replacing only member 2's stored stream.
    let patched_members = crate::tzz::parse_tzz(&patched_archive)?;
    ensure!(patched_members == master_members, "MGBGK04 TZZ geometry changed");
    ensure!(
        patched_archive[..master_member.offset] == master_archive[..master_member.offset],
        "MGBGK04 bytes before member 2 changed"
    );
    ensure!(
        patched_archive[master_member.offset + master_member.compressed_size..]
            == master_archive[master_member.offset + master_member.compressed_size..],
        "MGBGK04 bytes after member 2 compressed range changed"
    );

    fs::create_dir_all(
        output_bin.parent().context("output BIN has no parent")?
    )?;

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: RECORD_PATH,
        data: &patched_archive,
    }];

    let rebuilt_records =
        crate::disc::rebuild::copy_and_replace_records(master, output_bin, &replacements)?;
    ensure!(rebuilt_records.len() == 1, "v17h replaced more than MGBGK04.BZZ");

    let (_, readback_archive) =
        crate::disc::rebuild::read_record(output_bin, RECORD_PATH)?;
    ensure!(
        readback_archive == patched_archive,
        "MGBGK04.BZZ stored readback differs"
    );

    let readback_members = crate::tzz::parse_tzz(&readback_archive)?;
    let readback_member = readback_members[MEMBER_INDEX];
    let readback_decoded = crate::compression::decompress(
        &readback_archive[readback_member.compressed_range()],
        true,
    )?;
    ensure!(
        readback_decoded == patched_decoded,
        "MGBGK04 member 2 decoded readback differs"
    );
    ensure!(
        fs::metadata(master)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(master, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v17h changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt_records.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v17h changed sectors outside MGBGK04.BZZ"
    );

    let patched_tim = crate::embedded_tim::parse_embedded_tim_at(&patched_decoded, TIM_OFFSET)?;
    let preview_image =
        crate::embedded_tim::decode_embedded_tim_preview(&patched_decoded, &patched_tim)?;
    crate::tim_preview::write_tim_preview(preview, &preview_image)?;

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
        "kind": "Justice Gakuen 2 quiz fixed UI English v17h",
        "input_master_sha256": MASTER_SHA256,
        "source_bin_sha256": SOURCE_SHA256,
        "record_path": RECORD_PATH,
        "member_index": MEMBER_INDEX,
        "tim_offset": TIM_OFFSET,
        "source_archive_sha256": SOURCE_ARCHIVE_SHA256,
        "input_master_archive_sha256": crate::pipeline::sha256_bytes(&master_archive),
        "source_member_compressed_sha256": SOURCE_MEMBER_COMPRESSED_SHA256,
        "source_member_decoded_sha256": SOURCE_MEMBER_DECODED_SHA256,
        "input_master_member_compressed_sha256": crate::pipeline::sha256_bytes(master_compressed),
        "input_master_member_decoded_sha256": crate::pipeline::sha256_bytes(&master_decoded),
        "source_tim_sha256": SOURCE_TIM_SHA256,
        "patched_archive_sha256": crate::pipeline::sha256_bytes(&patched_archive),
        "patched_member_stored_sha256": crate::pipeline::sha256_bytes(&stored_member),
        "patched_member_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "patched_tim_sha256": patched_tim.source_tim_sha256,
        "rebuilt_compressed_size": rebuilt_compressed_size,
        "fixed_compressed_slot_size": master_member.compressed_size,
        "changed_indexed_pixel_count": changed_pixels,
        "changed_raw_sector_count": changed_lbas.len(),
        "output_sha256": output_sha256,
        "output_bin": output_bin,
        "output_cue": output_cue,
        "preview_png": preview,
        "translations": {
            "問題": "QUESTION",
            "正解": "CORRECT!",
            "不正解": "WRONG!",
            "試験終了": "EXAM OVER"
        },
        "palette_roles": {
            "correct": {
                "clear": correct_palette.0,
                "fill": correct_palette.1
            },
            "wrong": {
                "clear": wrong_palette.0,
                "fill": wrong_palette.1
            },
            "question": {
                "clear": question_palette.0,
                "fill": question_palette.1,
                "outline": question_palette.2
            },
            "exam_over": {
                "clear": exam_palette.0,
                "fill": exam_palette.1,
                "outline": exam_palette.2
            }
        }
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("QUIZ_FIXED_UI_V17H_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!(
        "PATCHED_MGBGK04_SHA256={}",
        crate::pipeline::sha256_bytes(&patched_archive)
    );
    eprintln!("CHANGED_INDEXED_PIXELS={changed_pixels}");
    eprintln!("REBUILT_MEMBER2_COMPRESSED_SIZE={rebuilt_compressed_size}");
    eprintln!("FIXED_MEMBER2_COMPRESSED_SLOT={}", master_member.compressed_size);
    eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
    eprintln!("CORRECT_PALETTE_CLEAR={} FILL={}", correct_palette.0, correct_palette.1);
    eprintln!("WRONG_PALETTE_CLEAR={} FILL={}", wrong_palette.0, wrong_palette.1);
    eprintln!(
        "QUESTION_PALETTE_CLEAR={} FILL={} OUTLINE={:?}",
        question_palette.0, question_palette.1, question_palette.2
    );
    eprintln!(
        "EXAM_PALETTE_CLEAR={} FILL={} OUTLINE={:?}",
        exam_palette.0, exam_palette.1, exam_palette.2
    );
    eprintln!("PREVIEW={}", preview.display());
    eprintln!("CUE={}", output_cue.display());

    Ok(())
}

"@

# Back up exact bytes before installing the temporary test. Never delete a prior run.
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
[System.IO.File]::WriteAllBytes($BackupPath, $OriginalRustBytes)
try {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "[1/2] Building QUESTION / CORRECT / WRONG / EXAM OVER graphics..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        # PowerShell 5.1 can turn native stderr into terminating error records.
        # Capture compiler diagnostics without mistaking stderr for failure.
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_quiz_fixed_ui_v17h -- --nocapture 2>&1 |
                Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $SavedPreference
        }
        if ($CargoExit -ne 0) {
            Fail ("Quiz UI build failed with exit code {0}. See {1}. The original Rust source will be restored." -f $CargoExit, $LogPath)
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllBytes($RustPath, $OriginalRustBytes)
    if ((Get-FileHash -LiteralPath $RustPath -Algorithm SHA256).Hash -ne $OriginalRustHash) {
        Fail ("Rust source restoration failed. The untouched backup is at {0}." -f $BackupPath)
    }
}

if (-not (Test-Path $OutputBin)) { Fail "v17h output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v17h output CUE missing." }
if (-not (Test-Path $PreviewPng)) { Fail "v17h atlas preview missing." }
if (-not (Test-Path $ReportJson)) { Fail "v17h report missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()
$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json

if ($OutputHash -ne [string]$Report.output_sha256) {
    Fail "PowerShell output SHA does not match Rust readback SHA."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "QUIZ FIXED UI ENGLISH v17h CANDIDATE BUILT" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed indexed pixels: {0}" -f $Report.changed_indexed_pixel_count)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_raw_sector_count)
Write-Host ("Member 2 compressed: {0} / {1}" -f $Report.rebuilt_compressed_size, $Report.fixed_compressed_slot_size)
Write-Host ""
Write-Host "Translated fixed quiz UI:" -ForegroundColor Yellow
Write-Host "  QUESTION"
Write-Host "  CORRECT!"
Write-Host "  WRONG!"
Write-Host "  EXAM OVER"
Write-Host ""
Write-Host "ATLAS PREVIEW:" -ForegroundColor Yellow
Write-Host $PreviewPng
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "Candidate only: test QUESTION, correct/wrong answers, EXAM OVER, and School Gate in-game." -ForegroundColor Yellow
Write-Host "Keep the v16 master until this candidate passes that test." -ForegroundColor Green

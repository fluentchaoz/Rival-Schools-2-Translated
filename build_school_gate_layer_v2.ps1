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
$DiarySceneSource = Join-Path $Upstream "src\diary_scene.rs"
$BaseBin = Join-Path $Upstream "work\english-road-to-batsu-blue-title\build\justice-gakuen2-road-to-batsu-blue-title.bin"
$ExpectedBaseHash = "ad068a54820b62bd246538e49776291512b88cab6447127fdd93ee6d4392dec4"
$OutputDir = Join-Path $Upstream "work\english-road-to-batsu-school-gate\build"
$OutputBin = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-school-gate.bin"
$OutputCue = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-school-gate.cue"
$ReportPath = Join-Path $OutputDir "school-gate-report.json"
$PreviewPath = Join-Path $OutputDir "school-gate-preview.png"
$Marker = "// ENGLISH_PROJECT_SCHOOL_GATE_PATCH_V1"

Write-Host ""
Write-Host "Justice Gakuen English Project - SCHOOL GATE layer" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream project directory beside this script." }
if (-not (Test-Path $DiarySceneSource)) { Fail "Missing upstream\src\diary_scene.rs." }
if (-not (Test-Path $BaseBin)) { Fail "Missing verified blue-title base BIN." }

$BaseHash = (Get-FileHash $BaseBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Base BIN SHA-256: {0}" -f $BaseHash)
if ($BaseHash -ne $ExpectedBaseHash) {
    Fail "Base BIN is not the exact verified ad068a... build. Nothing was changed."
}
Write-Host "Base hash verified." -ForegroundColor Green

if ([string]::IsNullOrWhiteSpace($FontPath)) {
    foreach ($Candidate in @(
        "C:\Windows\Fonts\arial.ttf",
        "C:\Windows\Fonts\segoeui.ttf",
        "C:\Windows\Fonts\calibri.ttf"
    )) {
        if (Test-Path $Candidate) {
            $FontPath = $Candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($FontPath) -or -not (Test-Path $FontPath)) {
    Fail "Could not find Arial, Segoe UI, or Calibri. Re-run with -FontPath pointing to an installed .ttf."
}
Write-Host ("Prototype font: {0}" -f $FontPath)

$OriginalSource = [System.IO.File]::ReadAllText($DiarySceneSource)
$ExistingMarker = $OriginalSource.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($ExistingMarker -ge 0) {
    Write-Host "Removing a stale SCHOOL GATE test injection from a previous interrupted run." -ForegroundColor Yellow
    $OriginalSource = $OriginalSource.Substring(0, $ExistingMarker).TrimEnd() + [Environment]::NewLine
    [System.IO.File]::WriteAllText($DiarySceneSource, $OriginalSource, [System.Text.UTF8Encoding]::new($false))
}

$RustPatch = @'

// ENGLISH_PROJECT_SCHOOL_GATE_PATCH_V1
#[cfg(test)]
mod english_school_gate_patch_v1 {
    use std::fs;
    use std::io::BufWriter;
    use std::path::{Path, PathBuf};

    use anyhow::{Context, Result, ensure};
    use serde_json::json;

    use crate::compression::{compress, decompress};
    use crate::disc::rebuild::{self, FixedRecordReplacement};
    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};
    use crate::pipeline::{sha256_bytes, sha256_file};
    use crate::tim::{Cell, read_8bpp_indexed_cell, write_8bpp_indexed_cell};
    use crate::tzz::parse_tzz;

    use super::runtime_bundle_build::encode_runtime_member;
    use super::source::{DIARY_SCENE_PATH, SOURCE_ARCHIVE_SHA256};

    const BASE_BIN_SHA256: &str =
        "ad068a54820b62bd246538e49776291512b88cab6447127fdd93ee6d4392dec4";
    const CATALOGUE_MEMBER_INDEX: usize = 57;
    const CATALOGUE_MEMBER_COMPRESSED_SHA256: &str =
        "b4e673d37ce181cfc1dd383abcce6a83473e77149716e5c0f8fa14641e21a7de";
    const CATALOGUE_MEMBER_DECODED_SHA256: &str =
        "99e2ba4116e0e4f08ffbeb1a759c57f8d0639af7fb1abed067567330f08e5871";
    const LOCATION_BLOCK_SHA256: &str =
        "060bb19baf2da827dee9fa17d07b361e6ed9a50ffdbe7b7ce1cdd0a3b88be3fa";

    const RUNTIME_PATH: &str = "DAT2/MGBGK03.BZZ";
    const RUNTIME_ARCHIVE_SHA256: &str =
        "a69e0643b05131c7dd028cb8a502bfe7615ca45930adfaaf0be09edd11ac8d55";

    struct RuntimeExpected {
        index: usize,
        compressed_sha256: &'static str,
        decoded_size: usize,
        decoded_sha256: &'static str,
    }

    const RUNTIME_TARGETS: &[RuntimeExpected] = &[
        RuntimeExpected {
            index: 2,
            compressed_sha256: "e66df4d0c8757882450004fee9e57e75034bde8f4a6b2f257811dbd7be7efc12",
            decoded_size: 282624,
            decoded_sha256: "ada5cc573ccfc1f9e81e28959eb7826a28a2ebf18ea65de7f91f4ac2465c3046",
        },
        RuntimeExpected {
            index: 15,
            compressed_sha256: "15157c7ab4cd9f1f5fcf4158bd9acc3970dca7e32cb73d3b5a9df0fa5b653071",
            decoded_size: 344064,
            decoded_sha256: "b07dcc9ba6ff108bab0d3d3e583f579984bd6a7ff8d0b4b492c2d67ba2436fdd",
        },
        RuntimeExpected {
            index: 20,
            compressed_sha256: "0ea5e302e5a14e0d007d9e8f4ff7aa38b923544560a32c875b60b2e6467c1f83",
            decoded_size: 266240,
            decoded_sha256: "dba8b1d344d1303f0ebdcd651a13c068e6069dd2587b2531c42b29b1daa541eb",
        },
        RuntimeExpected {
            index: 23,
            compressed_sha256: "b7721a864b24826b216f9d3028e142f389268f2852dbd3e94ec3ee4827cc2ce6",
            decoded_size: 258048,
            decoded_sha256: "f26127e1e57520580a03bb88dd1c11124a0f48bab997bf355e4fb86e4c7ba2ac",
        },
        RuntimeExpected {
            index: 25,
            compressed_sha256: "d92bda3eaebb580cb554b474ca2d894af28196d92e12c4f21a8bddb3b003a5b8",
            decoded_size: 374784,
            decoded_sha256: "ba557f67d712273283b9f800958ea17064538da62a70fbff3b7ec422aafbf3fa",
        },
    ];

    fn changed_ranges(values: &[u32]) -> Vec<[u32; 2]> {
        let Some((&first, rest)) = values.split_first() else {
            return Vec::new();
        };
        let mut out = Vec::new();
        let mut start = first;
        let mut previous = first;
        for &value in rest {
            if value == previous + 1 {
                previous = value;
            } else {
                out.push([start, previous]);
                start = value;
                previous = value;
            }
        }
        out.push([start, previous]);
        out
    }

    fn changes_confined_to_ranges(source: &[u8], output: &[u8], ranges: &[std::ops::Range<usize>]) -> bool {
        source.len() == output.len()
            && source.iter().zip(output).enumerate().all(|(offset, (a, b))| {
                a == b || ranges.iter().any(|range| range.contains(&offset))
            })
    }

    fn write_location_preview_png(path: &Path, decoded: &[u8], cell: Cell) -> Result<()> {
        // 8-bpp TIM: first CLUT starts at byte 20 and contains 256 BGR555 words.
        ensure!(decoded.len() >= 20 + 512, "TIM palette is truncated");
        let indexed = read_8bpp_indexed_cell(decoded, cell)?;
        let scale = 4usize;
        let width = cell.width * scale;
        let height = cell.height * scale;
        let mut rgb = Vec::with_capacity(width * height * 3);
        for y in 0..height {
            for x in 0..width {
                let index = usize::from(indexed[(y / scale) * cell.width + x / scale]);
                let at = 20 + index * 2;
                let value = u16::from_le_bytes([decoded[at], decoded[at + 1]]);
                let r5 = (value & 0x1f) as u8;
                let g5 = ((value >> 5) & 0x1f) as u8;
                let b5 = ((value >> 10) & 0x1f) as u8;
                let expand = |v: u8| -> u8 { ((u16::from(v) * 255 + 15) / 31) as u8 };
                rgb.extend_from_slice(&[expand(r5), expand(g5), expand(b5)]);
            }
        }
        let file = fs::File::create(path)
            .with_context(|| format!("failed to create {}", path.display()))?;
        let mut encoder = png::Encoder::new(BufWriter::new(file), width as u32, height as u32);
        encoder.set_color(png::ColorType::Rgb);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header()?;
        writer.write_image_data(&rgb)?;
        Ok(())
    }

    #[test]
    fn english_school_gate_patch_v1() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("justice-gakuen2-school-gate-large-stack".to_string())
            .stack_size(64 * 1024 * 1024)
            .spawn(run_school_gate_patch)?;
        match worker.join() {
            Ok(result) => result,
            Err(payload) => std::panic::resume_unwind(payload),
        }
    }

    fn run_school_gate_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input_bin = root.join(
            "work/english-road-to-batsu-blue-title/build/justice-gakuen2-road-to-batsu-blue-title.bin",
        );
        let output_root = root.join("work/english-road-to-batsu-school-gate");
        let build_dir = output_root.join("build");
        let output_bin = build_dir.join("justice-gakuen2-road-to-batsu-school-gate.bin");
        let output_cue = build_dir.join("justice-gakuen2-road-to-batsu-school-gate.cue");
        let report_path = build_dir.join("school-gate-report.json");
        let preview_path = build_dir.join("school-gate-preview.png");

        ensure!(input_bin.is_file(), "verified blue-title input BIN is missing");
        ensure!(sha256_file(&input_bin)? == BASE_BIN_SHA256, "blue-title input BIN hash changed");

        let font_path = PathBuf::from(
            std::env::var("JG_SCHOOL_GATE_FONT")
                .context("JG_SCHOOL_GATE_FONT was not provided by the PowerShell wrapper")?,
        );
        ensure!(font_path.is_file(), "prototype font is missing: {}", font_path.display());

        if output_root.exists() {
            fs::remove_dir_all(&output_root)?;
        }
        fs::create_dir_all(&build_dir)?;

        eprintln!("school-gate: reading and verifying {DIARY_SCENE_PATH} member 57");
        let (_, source_catalogue) = rebuild::read_record(&input_bin, DIARY_SCENE_PATH)?;
        ensure!(sha256_bytes(&source_catalogue) == SOURCE_ARCHIVE_SHA256, "MGBG.TZZ source archive changed");
        let catalogue_slots = parse_tzz(&source_catalogue)?;
        ensure!(catalogue_slots.len() == 112, "MGBG.TZZ member count changed");
        let catalogue_slot = catalogue_slots[CATALOGUE_MEMBER_INDEX];
        let source_catalogue_compressed = &source_catalogue[catalogue_slot.compressed_range()];
        ensure!(
            sha256_bytes(source_catalogue_compressed) == CATALOGUE_MEMBER_COMPRESSED_SHA256,
            "MGBG.TZZ member 57 compressed source changed"
        );
        let source_catalogue_decoded = decompress(source_catalogue_compressed, false)?;
        ensure!(
            sha256_bytes(&source_catalogue_decoded) == CATALOGUE_MEMBER_DECODED_SHA256,
            "MGBG.TZZ member 57 decoded source changed"
        );

        let location_block = Cell { x: 0, y: 220, width: 128, height: 24 };
        let source_location = read_8bpp_indexed_cell(&source_catalogue_decoded, location_block)?;
        ensure!(
            sha256_bytes(&source_location) == LOCATION_BLOCK_SHA256,
            "member 57 location strip changed"
        );

        // Native 正門前 ink starts at x=8 in this 128x24 strip. Clear the owned strip,
        // then render English from the same inset. Writing clear index 0 over already-clear
        // pixels is byte-identical, so no neighboring artwork is altered.
        let text_cell = Cell { x: 8, y: 220, width: 120, height: 24 };
        let rasterizer = IndexedTextRasterizer::load(&font_path)?;
        let mut selected = None;
        let mut last_error = None;
        for font_px in [18.0_f32, 17.0, 16.0, 15.0] {
            match rasterizer.rasterize(
                "SCHOOL GATE",
                text_cell.width,
                text_cell.height,
                font_px,
                0.0,
                0,
                Some(2),
                241,
                HorizontalTextAlignment::Left,
            ) {
                Ok(raster) => {
                    selected = Some((font_px, raster));
                    break;
                }
                Err(error) => last_error = Some(error.to_string()),
            }
        }
        let (font_px, raster) = selected.with_context(|| {
            format!(
                "SCHOOL GATE did not fit the native location strip; last raster error: {}",
                last_error.unwrap_or_else(|| "unknown".to_string())
            )
        })?;

        let mut patched_catalogue_decoded = source_catalogue_decoded.clone();
        write_8bpp_indexed_cell(
            &mut patched_catalogue_decoded,
            location_block,
            &vec![0u8; location_block.width * location_block.height],
        )?;
        write_8bpp_indexed_cell(&mut patched_catalogue_decoded, text_cell, &raster.pixels)?;
        ensure!(
            patched_catalogue_decoded.len() == source_catalogue_decoded.len(),
            "member 57 decoded extent changed"
        );
        ensure!(
            patched_catalogue_decoded != source_catalogue_decoded,
            "SCHOOL GATE produced no decoded change"
        );

        let patched_catalogue_stream = compress(&patched_catalogue_decoded, 0)?;
        ensure!(
            patched_catalogue_stream.len() <= catalogue_slot.compressed_size,
            "rebuilt MGBG.TZZ member 57 needs {} bytes but owns {}",
            patched_catalogue_stream.len(),
            catalogue_slot.compressed_size
        );
        let mut patched_catalogue_stored = vec![0u8; catalogue_slot.compressed_size];
        patched_catalogue_stored[..patched_catalogue_stream.len()]
            .copy_from_slice(&patched_catalogue_stream);
        ensure!(
            decompress(&patched_catalogue_stored, true)? == patched_catalogue_decoded,
            "member 57 compression readback failed"
        );

        let mut patched_catalogue = source_catalogue.clone();
        patched_catalogue[catalogue_slot.compressed_range()]
            .copy_from_slice(&patched_catalogue_stored);
        ensure!(
            parse_tzz(&patched_catalogue)? == catalogue_slots,
            "MGBG.TZZ member table changed"
        );
        ensure!(
            changes_confined_to_ranges(
                &source_catalogue,
                &patched_catalogue,
                &[catalogue_slot.compressed_range()]
            ),
            "MGBG.TZZ changed outside member 57"
        );

        eprintln!("school-gate: propagating member 57 into five MGBGK03 runtime members");
        let (_, source_runtime) = rebuild::read_record(&input_bin, RUNTIME_PATH)?;
        ensure!(sha256_bytes(&source_runtime) == RUNTIME_ARCHIVE_SHA256, "MGBGK03.BZZ source archive changed");
        let runtime_slots = parse_tzz(&source_runtime)?;
        ensure!(runtime_slots.len() == 52, "MGBGK03.BZZ member count changed");
        let mut patched_runtime = source_runtime.clone();
        let mut runtime_reports = Vec::new();
        let mut owned_runtime_ranges = Vec::new();

        for expected in RUNTIME_TARGETS {
            let slot = runtime_slots[expected.index];
            let source_compressed = &source_runtime[slot.compressed_range()];
            ensure!(
                sha256_bytes(source_compressed) == expected.compressed_sha256,
                "runtime member {} compressed source changed",
                expected.index
            );
            let source_decoded = decompress(source_compressed, true)?;
            ensure!(
                source_decoded.len() == expected.decoded_size
                    && sha256_bytes(&source_decoded) == expected.decoded_sha256,
                "runtime member {} decoded source changed",
                expected.index
            );
            ensure!(
                source_decoded.starts_with(&source_catalogue_decoded),
                "runtime member {} no longer starts with catalogue member 57",
                expected.index
            );

            let mut patched_decoded = source_decoded.clone();
            patched_decoded[..patched_catalogue_decoded.len()]
                .copy_from_slice(&patched_catalogue_decoded);
            ensure!(
                patched_decoded[source_catalogue_decoded.len()..]
                    == source_decoded[source_catalogue_decoded.len()..],
                "runtime member {} trailing decoded data changed",
                expected.index
            );

            let encoding = encode_runtime_member(source_compressed, &source_decoded, &patched_decoded)
                .with_context(|| format!("failed native-safe runtime encoding for member {}", expected.index))?;
            let rebuilt_size = encoding.bytes.len();
            ensure!(
                rebuilt_size <= slot.compressed_size,
                "runtime member {} needs {} bytes but owns {}",
                expected.index,
                rebuilt_size,
                slot.compressed_size
            );
            let mut stored = vec![0u8; slot.compressed_size];
            stored[..rebuilt_size].copy_from_slice(&encoding.bytes);
            ensure!(
                decompress(&stored, true)? == patched_decoded,
                "runtime member {} stored readback failed",
                expected.index
            );
            patched_runtime[slot.compressed_range()].copy_from_slice(&stored);
            owned_runtime_ranges.push(slot.compressed_range());
            runtime_reports.push(json!({
                "index": expected.index,
                "source_compressed_sha256": expected.compressed_sha256,
                "patched_compressed_sha256": sha256_bytes(&stored),
                "source_decoded_sha256": expected.decoded_sha256,
                "patched_decoded_sha256": sha256_bytes(&patched_decoded),
                "source_compressed_size": slot.compressed_size,
                "rebuilt_stream_size": rebuilt_size,
                "trailing_decoded_bytes_preserved": true
            }));
        }

        ensure!(parse_tzz(&patched_runtime)? == runtime_slots, "MGBGK03.BZZ member table changed");
        ensure!(
            changes_confined_to_ranges(&source_runtime, &patched_runtime, &owned_runtime_ranges),
            "MGBGK03.BZZ changed outside the five member-57 consumers"
        );

        eprintln!("school-gate: writing two-record disc layer");
        let replacements = [
            FixedRecordReplacement { path: DIARY_SCENE_PATH, data: &patched_catalogue },
            FixedRecordReplacement { path: RUNTIME_PATH, data: &patched_runtime },
        ];
        let rebuilt_records = rebuild::copy_and_replace_records(&input_bin, &output_bin, &replacements)?;
        ensure!(rebuilt_records.len() == 2, "disc rebuild did not replace exactly two records");

        let (_, catalogue_readback) = rebuild::read_record(&output_bin, DIARY_SCENE_PATH)?;
        let (_, runtime_readback) = rebuild::read_record(&output_bin, RUNTIME_PATH)?;
        ensure!(catalogue_readback == patched_catalogue, "MGBG.TZZ disc readback failed");
        ensure!(runtime_readback == patched_runtime, "MGBGK03.BZZ disc readback failed");
        ensure!(
            fs::metadata(&input_bin)?.len() == fs::metadata(&output_bin)?.len(),
            "disc image length changed"
        );

        let (changed_lbas, output_sha256) = rebuild::compare_and_hash_images(&input_bin, &output_bin)?;
        ensure!(!changed_lbas.is_empty(), "school-gate build changed no disc sectors");

        write_location_preview_png(&preview_path, &patched_catalogue_decoded, location_block)?;

        let bin_name = output_bin
            .file_name()
            .context("output BIN has no filename")?
            .to_string_lossy();
        fs::write(
            &output_cue,
            format!("FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"),
        )?;

        let report = json!({
            "kind": "Justice Gakuen 2 English SCHOOL GATE prototype",
            "input_bin": input_bin.display().to_string(),
            "input_bin_sha256": BASE_BIN_SHA256,
            "output_bin": output_bin.display().to_string(),
            "output_bin_sha256": output_sha256.clone(),
            "output_cue": output_cue.display().to_string(),
            "catalogue_path": DIARY_SCENE_PATH,
            "catalogue_member_index": CATALOGUE_MEMBER_INDEX,
            "source_location_block_sha256": LOCATION_BLOCK_SHA256,
            "patched_location_block_sha256": sha256_bytes(&read_8bpp_indexed_cell(&patched_catalogue_decoded, location_block)?),
            "english_text": "SCHOOL GATE",
            "font_path": font_path.display().to_string(),
            "font_px": font_px,
            "font_sha256": raster.font_sha256,
            "font_name": raster.font_name,
            "text_cell": {"x": text_cell.x, "y": text_cell.y, "width": text_cell.width, "height": text_cell.height},
            "palette": {"clear_index": 0, "outline_index": 2, "fill_index": 241},
            "catalogue_source_compressed_sha256": CATALOGUE_MEMBER_COMPRESSED_SHA256,
            "catalogue_source_decoded_sha256": CATALOGUE_MEMBER_DECODED_SHA256,
            "catalogue_patched_decoded_sha256": sha256_bytes(&patched_catalogue_decoded),
            "catalogue_rebuilt_stream_size": patched_catalogue_stream.len(),
            "catalogue_stored_size": catalogue_slot.compressed_size,
            "runtime_path": RUNTIME_PATH,
            "runtime_members": runtime_reports,
            "replaced_iso_record_count": rebuilt_records.len(),
            "changed_sector_count": changed_lbas.len(),
            "changed_lba_ranges": changed_ranges(&changed_lbas),
            "readback_verified": true,
            "source_image_length_preserved": true,
            "changes_confined_to_catalogue_member_57": true,
            "changes_confined_to_five_runtime_consumers": true,
            "preview_png": preview_path.display().to_string()
        });
        let mut report_bytes = serde_json::to_vec_pretty(&report)?;
        report_bytes.push(b'\n');
        fs::write(&report_path, report_bytes)?;

        eprintln!("school-gate: COMPLETE");
        eprintln!("school-gate: output BIN SHA-256 {output_sha256}");
        eprintln!("school-gate: {} changed raw sectors", changed_lbas.len());
        eprintln!("school-gate: output CUE {}", output_cue.display());
        eprintln!("school-gate: preview {}", preview_path.display());
        Ok(())
    }
}

'@

$InjectedSource = $OriginalSource.TrimEnd() + [Environment]::NewLine + $RustPatch + [Environment]::NewLine
$OldFontEnv = $env:JG_SCHOOL_GATE_FONT
$BuildSucceeded = $false

try {
    [System.IO.File]::WriteAllText(
        $DiarySceneSource,
        $InjectedSource,
        [System.Text.UTF8Encoding]::new($false)
    )

    $env:JG_SCHOOL_GATE_FONT = $FontPath

    Write-Host ""
    Write-Host "Building source-bound SCHOOL GATE layer..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @("test", "--lib", "english_school_gate_patch_v1", "--", "--nocapture")
    }
    finally {
        Pop-Location
    }

    $BuildSucceeded = $true
}
catch {
    Write-Host ""
    Write-Host "FIRST BUILD ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    throw
}
finally {
    # Never leave the temporary Rust test installed in the user's research tree.
    [System.IO.File]::WriteAllText(
        $DiarySceneSource,
        $OriginalSource,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ($null -eq $OldFontEnv) {
        Remove-Item Env:JG_SCHOOL_GATE_FONT -ErrorAction SilentlyContinue
    }
    else {
        $env:JG_SCHOOL_GATE_FONT = $OldFontEnv
    }
}

if (-not $BuildSucceeded) { Fail "SCHOOL GATE build did not complete." }
if (-not (Test-Path $OutputBin)) { Fail "Build reported success but output BIN is missing." }
if (-not (Test-Path $OutputCue)) { Fail "Build reported success but output CUE is missing." }
if (-not (Test-Path $ReportPath)) { Fail "Build reported success but verification report is missing." }
if (-not (Test-Path $PreviewPath)) { Fail "Build reported success but SCHOOL GATE preview PNG is missing." }

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()
if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "Final PowerShell SHA-256 does not match the Rust readback report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "SCHOOL GATE BUILD COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ("Rendered font size: {0}px" -f $Report.font_px)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Cyan
Write-Host $OutputCue
Write-Host ""
Write-Host "PREVIEW PNG:" -ForegroundColor Cyan
Write-Host $PreviewPath
Write-Host ""
Write-Host "VERIFICATION REPORT:" -ForegroundColor Cyan
Write-Host $ReportPath
Write-Host ""
Write-Host "Your existing ad068a blue-title build was left untouched." -ForegroundColor Green

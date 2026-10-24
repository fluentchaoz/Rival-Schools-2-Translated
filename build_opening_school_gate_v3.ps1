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

$OutputDir = Join-Path $Upstream "work\english-road-to-batsu-opening-school-gate\build"
$OutputBin = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-opening-school-gate.bin"
$OutputCue = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-opening-school-gate.cue"
$ReportPath = Join-Path $OutputDir "opening-school-gate-report.json"
$PreviewPath = Join-Path $OutputDir "opening-school-gate-preview.png"

$Marker = "// ENGLISH_PROJECT_OPENING_SCHOOL_GATE_PATCH_V3"

Write-Host ""
Write-Host "Justice Gakuen English Project - OPENING SCHOOL GATE layer v3" -ForegroundColor Cyan
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
    Write-Host "Removing a stale opening-school-gate test injection from a previous interrupted run." -ForegroundColor Yellow
    $OriginalSource = $OriginalSource.Substring(0, $ExistingMarker).TrimEnd() + [Environment]::NewLine
    [System.IO.File]::WriteAllText($DiarySceneSource, $OriginalSource, [System.Text.UTF8Encoding]::new($false))
}

$RustPatch = @'

// ENGLISH_PROJECT_OPENING_SCHOOL_GATE_PATCH_V3
#[cfg(test)]
mod english_opening_school_gate_patch_v3 {
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

    // Actual opening scene shown in the supplied screenshot:
    // 校門前 ("in front of the school gate").
    const CATALOGUE_MEMBER_INDEX: usize = 6;
    const CATALOGUE_MEMBER_COMPRESSED_SHA256: &str =
        "abf94648b71542ead60d41e79b20da37e059b97fe0f320fb1c6eb6f1794ba13a";
    const CATALOGUE_MEMBER_DECODED_SHA256: &str =
        "018c13d116c56c19346dbced00c0a16719802fdd7979491dc7734b992a9ad33d";
    const LOCATION_BLOCK_SHA256: &str =
        "d6010381d3f01556f4f2f2598748eff7172d55852e5f0e3e54efce2bd8ba381a";

    struct RuntimeExpected {
        index: usize,
        compressed_sha256: &'static str,
        decoded_size: usize,
        decoded_sha256: &'static str,
    }

    const MGBGE03_TARGETS: &[RuntimeExpected] = &[
        RuntimeExpected {
            index: 4,
            compressed_sha256: "e8eca4d7dc2c28304aa66d5f0cf161efd02fad8dadffe51b5cd1c4c9e1427177",
            decoded_size: 407552,
            decoded_sha256: "f94d92fb45870af9c3ac2b982ea46ca53cb73db6538309369e9ba11cf68dfc7a",
        },
        RuntimeExpected {
            index: 12,
            compressed_sha256: "0fbd3aa8224356821f5560c34882fc5dae46d7fc4a8961b501a7d980571f2938",
            decoded_size: 401408,
            decoded_sha256: "eec43bedee2fc3d6f15057e26caf5c16ddba9c069c72ca312b9341e72d77fed0",
        },
    ];

    const MGBGK02_TARGETS: &[RuntimeExpected] = &[
        RuntimeExpected {
            index: 26,
            compressed_sha256: "36f7f1ea30334bd42ed6be3e4a5fecb7464006873cc589ba184ecaef963630d9",
            decoded_size: 63488,
            decoded_sha256: "d29af9f8f1ab55e291fbce9c4861a96d99bfbfe0d547f1784a9fd88257dfca89",
        },
    ];

    const MGBGK04_TARGETS: &[RuntimeExpected] = &[
        RuntimeExpected {
            index: 0,
            compressed_sha256: "d4bd104ed72ae3e65ef638d10f55ba636b71a071dd3ea233de7c777f5f3ddc93",
            decoded_size: 176128,
            decoded_sha256: "b44b28bd2e02a8206379c6dc198e40e707596e18ba417f37843b786d11575bc3",
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

    fn changes_confined_to_ranges(
        source: &[u8],
        output: &[u8],
        ranges: &[std::ops::Range<usize>],
    ) -> bool {
        source.len() == output.len()
            && source.iter().zip(output).enumerate().all(|(offset, (a, b))| {
                a == b || ranges.iter().any(|range| range.contains(&offset))
            })
    }

    fn write_location_preview_png(path: &Path, decoded: &[u8], cell: Cell) -> Result<()> {
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

    fn patch_runtime_archive(
        input_bin: &Path,
        path: &str,
        expected_archive_sha256: &str,
        expected_member_count: usize,
        targets: &[RuntimeExpected],
        source_catalogue_decoded: &[u8],
        patched_catalogue_decoded: &[u8],
    ) -> Result<(Vec<u8>, Vec<serde_json::Value>)> {
        let (_, source_runtime) = rebuild::read_record(input_bin, path)?;
        ensure!(
            sha256_bytes(&source_runtime) == expected_archive_sha256,
            "{} source archive changed",
            path
        );
        let runtime_slots = parse_tzz(&source_runtime)?;
        ensure!(
            runtime_slots.len() == expected_member_count,
            "{} member count changed",
            path
        );

        let mut patched_runtime = source_runtime.clone();
        let mut reports = Vec::new();
        let mut owned_ranges = Vec::new();

        for expected in targets {
            let slot = runtime_slots[expected.index];
            let source_compressed = &source_runtime[slot.compressed_range()];
            ensure!(
                sha256_bytes(source_compressed) == expected.compressed_sha256,
                "{} member {} compressed source changed",
                path,
                expected.index
            );

            let source_decoded = decompress(source_compressed, true)?;
            ensure!(
                source_decoded.len() == expected.decoded_size
                    && sha256_bytes(&source_decoded) == expected.decoded_sha256,
                "{} member {} decoded source changed",
                path,
                expected.index
            );
            ensure!(
                source_decoded.starts_with(source_catalogue_decoded),
                "{} member {} no longer starts with catalogue member 6",
                path,
                expected.index
            );

            let mut patched_decoded = source_decoded.clone();
            patched_decoded[..patched_catalogue_decoded.len()]
                .copy_from_slice(patched_catalogue_decoded);

            ensure!(
                patched_decoded[source_catalogue_decoded.len()..]
                    == source_decoded[source_catalogue_decoded.len()..],
                "{} member {} trailing decoded data changed",
                path,
                expected.index
            );

            let encoding =
                encode_runtime_member(source_compressed, &source_decoded, &patched_decoded)
                    .with_context(|| {
                        format!(
                            "failed native-safe runtime encoding for {} member {}",
                            path, expected.index
                        )
                    })?;

            let rebuilt_size = encoding.bytes.len();
            ensure!(
                rebuilt_size <= slot.compressed_size,
                "{} member {} needs {} bytes but owns {}",
                path,
                expected.index,
                rebuilt_size,
                slot.compressed_size
            );

            let mut stored = vec![0u8; slot.compressed_size];
            stored[..rebuilt_size].copy_from_slice(&encoding.bytes);
            ensure!(
                decompress(&stored, true)? == patched_decoded,
                "{} member {} stored readback failed",
                path,
                expected.index
            );

            patched_runtime[slot.compressed_range()].copy_from_slice(&stored);
            owned_ranges.push(slot.compressed_range());

            reports.push(json!({
                "path": path,
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

        ensure!(
            parse_tzz(&patched_runtime)? == runtime_slots,
            "{} member table changed",
            path
        );
        ensure!(
            changes_confined_to_ranges(&source_runtime, &patched_runtime, &owned_ranges),
            "{} changed outside member-6 consumers",
            path
        );

        Ok((patched_runtime, reports))
    }

    #[test]
    fn english_opening_school_gate_patch_v3() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("justice-gakuen2-opening-school-gate-large-stack".to_string())
            .stack_size(64 * 1024 * 1024)
            .spawn(run_patch)?;
        match worker.join() {
            Ok(result) => result,
            Err(payload) => std::panic::resume_unwind(payload),
        }
    }

    fn run_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input_bin = root.join(
            "work/english-road-to-batsu-blue-title/build/justice-gakuen2-road-to-batsu-blue-title.bin",
        );

        let output_root = root.join("work/english-road-to-batsu-opening-school-gate");
        let build_dir = output_root.join("build");
        let output_bin =
            build_dir.join("justice-gakuen2-road-to-batsu-opening-school-gate.bin");
        let output_cue =
            build_dir.join("justice-gakuen2-road-to-batsu-opening-school-gate.cue");
        let report_path = build_dir.join("opening-school-gate-report.json");
        let preview_path = build_dir.join("opening-school-gate-preview.png");

        ensure!(input_bin.is_file(), "verified blue-title input BIN is missing");
        ensure!(
            sha256_file(&input_bin)? == BASE_BIN_SHA256,
            "blue-title input BIN hash changed"
        );

        let font_path = PathBuf::from(
            std::env::var("JG_OPENING_SCHOOL_GATE_FONT")
                .context("JG_OPENING_SCHOOL_GATE_FONT was not provided")?,
        );
        ensure!(
            font_path.is_file(),
            "prototype font is missing: {}",
            font_path.display()
        );

        if output_root.exists() {
            fs::remove_dir_all(&output_root)?;
        }
        fs::create_dir_all(&build_dir)?;

        eprintln!("opening-school-gate: verifying MGBG.TZZ member 6");
        let (_, source_catalogue) = rebuild::read_record(&input_bin, DIARY_SCENE_PATH)?;
        ensure!(
            sha256_bytes(&source_catalogue) == SOURCE_ARCHIVE_SHA256,
            "MGBG.TZZ source archive changed"
        );
        let catalogue_slots = parse_tzz(&source_catalogue)?;
        ensure!(catalogue_slots.len() == 112, "MGBG.TZZ member count changed");

        let catalogue_slot = catalogue_slots[CATALOGUE_MEMBER_INDEX];
        let source_catalogue_compressed =
            &source_catalogue[catalogue_slot.compressed_range()];

        ensure!(
            sha256_bytes(source_catalogue_compressed)
                == CATALOGUE_MEMBER_COMPRESSED_SHA256,
            "MGBG.TZZ member 6 compressed source changed"
        );

        let source_catalogue_decoded =
            decompress(source_catalogue_compressed, false)?;
        ensure!(
            sha256_bytes(&source_catalogue_decoded)
                == CATALOGUE_MEMBER_DECODED_SHA256,
            "MGBG.TZZ member 6 decoded source changed"
        );

        let location_block = Cell {
            x: 0,
            y: 220,
            width: 128,
            height: 24,
        };
        let source_location =
            read_8bpp_indexed_cell(&source_catalogue_decoded, location_block)?;
        ensure!(
            sha256_bytes(&source_location) == LOCATION_BLOCK_SHA256,
            "member 6 location strip changed"
        );

        // Native 校門前 begins around x=10. Reuse the same 128x24 owned label strip.
        let text_cell = Cell {
            x: 8,
            y: 220,
            width: 120,
            height: 24,
        };

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
                Some(1),
                255,
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
        write_8bpp_indexed_cell(
            &mut patched_catalogue_decoded,
            text_cell,
            &raster.pixels,
        )?;

        ensure!(
            patched_catalogue_decoded.len() == source_catalogue_decoded.len(),
            "member 6 decoded extent changed"
        );
        ensure!(
            patched_catalogue_decoded != source_catalogue_decoded,
            "SCHOOL GATE produced no decoded change"
        );

        let patched_catalogue_stream = compress(&patched_catalogue_decoded, 0)?;
        ensure!(
            patched_catalogue_stream.len() <= catalogue_slot.compressed_size,
            "rebuilt MGBG.TZZ member 6 needs {} bytes but owns {}",
            patched_catalogue_stream.len(),
            catalogue_slot.compressed_size
        );

        let mut patched_catalogue_stored =
            vec![0u8; catalogue_slot.compressed_size];
        patched_catalogue_stored[..patched_catalogue_stream.len()]
            .copy_from_slice(&patched_catalogue_stream);

        ensure!(
            decompress(&patched_catalogue_stored, true)?
                == patched_catalogue_decoded,
            "member 6 compression readback failed"
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
            "MGBG.TZZ changed outside member 6"
        );

        eprintln!("opening-school-gate: propagating member 6 into four runtime consumers");

        let (patched_mgbge03, mut runtime_reports) = patch_runtime_archive(
            &input_bin,
            "DAT2/MGBGE03.BZZ",
            "733a3d1ac2b9bf2ed0ebdc6eacc508466a2e26be77e0694dc0d1872b0009d55f",
            24,
            MGBGE03_TARGETS,
            &source_catalogue_decoded,
            &patched_catalogue_decoded,
        )?;

        let (patched_mgbgk02, reports) = patch_runtime_archive(
            &input_bin,
            "DAT2/MGBGK02.BZZ",
            "f520b1780fc86f551c14f7050793ff67b31bd4d9575eb179cece6a3ce7fbd6a9",
            66,
            MGBGK02_TARGETS,
            &source_catalogue_decoded,
            &patched_catalogue_decoded,
        )?;
        runtime_reports.extend(reports);

        let (patched_mgbgk04, reports) = patch_runtime_archive(
            &input_bin,
            "DAT2/MGBGK04.BZZ",
            "c45932c3ae22706250f3db1c000d9f8911a475083bd74e485c6daebbb3167558",
            3,
            MGBGK04_TARGETS,
            &source_catalogue_decoded,
            &patched_catalogue_decoded,
        )?;
        runtime_reports.extend(reports);

        eprintln!("opening-school-gate: writing four-record disc layer");

        let replacements = [
            FixedRecordReplacement {
                path: DIARY_SCENE_PATH,
                data: &patched_catalogue,
            },
            FixedRecordReplacement {
                path: "DAT2/MGBGE03.BZZ",
                data: &patched_mgbge03,
            },
            FixedRecordReplacement {
                path: "DAT2/MGBGK02.BZZ",
                data: &patched_mgbgk02,
            },
            FixedRecordReplacement {
                path: "DAT2/MGBGK04.BZZ",
                data: &patched_mgbgk04,
            },
        ];

        let rebuilt_records =
            rebuild::copy_and_replace_records(&input_bin, &output_bin, &replacements)?;
        ensure!(
            rebuilt_records.len() == 4,
            "disc rebuild did not replace exactly four records"
        );

        let (_, readback_catalogue) =
            rebuild::read_record(&output_bin, DIARY_SCENE_PATH)?;
        let (_, readback_e03) =
            rebuild::read_record(&output_bin, "DAT2/MGBGE03.BZZ")?;
        let (_, readback_k02) =
            rebuild::read_record(&output_bin, "DAT2/MGBGK02.BZZ")?;
        let (_, readback_k04) =
            rebuild::read_record(&output_bin, "DAT2/MGBGK04.BZZ")?;

        ensure!(
            readback_catalogue == patched_catalogue,
            "MGBG.TZZ disc readback failed"
        );
        ensure!(readback_e03 == patched_mgbge03, "MGBGE03.BZZ readback failed");
        ensure!(readback_k02 == patched_mgbgk02, "MGBGK02.BZZ readback failed");
        ensure!(readback_k04 == patched_mgbgk04, "MGBGK04.BZZ readback failed");

        ensure!(
            fs::metadata(&input_bin)?.len() == fs::metadata(&output_bin)?.len(),
            "disc image length changed"
        );

        let (changed_lbas, output_sha256) =
            rebuild::compare_and_hash_images(&input_bin, &output_bin)?;
        ensure!(
            !changed_lbas.is_empty(),
            "opening SCHOOL GATE build changed no disc sectors"
        );

        write_location_preview_png(
            &preview_path,
            &patched_catalogue_decoded,
            location_block,
        )?;

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
            "kind": "Justice Gakuen 2 English opening SCHOOL GATE prototype v3",
            "input_bin": input_bin.display().to_string(),
            "input_bin_sha256": BASE_BIN_SHA256,
            "output_bin": output_bin.display().to_string(),
            "output_bin_sha256": output_sha256.clone(),
            "output_cue": output_cue.display().to_string(),
            "catalogue_path": DIARY_SCENE_PATH,
            "catalogue_member_index": CATALOGUE_MEMBER_INDEX,
            "source_location_block_sha256": LOCATION_BLOCK_SHA256,
            "patched_location_block_sha256":
                sha256_bytes(&read_8bpp_indexed_cell(
                    &patched_catalogue_decoded,
                    location_block
                )?),
            "english_text": "SCHOOL GATE",
            "font_path": font_path.display().to_string(),
            "font_px": font_px,
            "font_sha256": raster.font_sha256,
            "font_name": raster.font_name,
            "text_cell": {
                "x": text_cell.x,
                "y": text_cell.y,
                "width": text_cell.width,
                "height": text_cell.height
            },
            "palette": {
                "clear_index": 0,
                "outline_index": 1,
                "fill_index": 255
            },
            "catalogue_source_compressed_sha256":
                CATALOGUE_MEMBER_COMPRESSED_SHA256,
            "catalogue_source_decoded_sha256":
                CATALOGUE_MEMBER_DECODED_SHA256,
            "catalogue_patched_decoded_sha256":
                sha256_bytes(&patched_catalogue_decoded),
            "catalogue_rebuilt_stream_size":
                patched_catalogue_stream.len(),
            "catalogue_stored_size":
                catalogue_slot.compressed_size,
            "runtime_members": runtime_reports,
            "replaced_iso_record_count": rebuilt_records.len(),
            "changed_sector_count": changed_lbas.len(),
            "changed_lba_ranges": changed_ranges(&changed_lbas),
            "readback_verified": true,
            "source_image_length_preserved": true,
            "changes_confined_to_catalogue_member_6": true,
            "changes_confined_to_four_runtime_consumers": true,
            "preview_png": preview_path.display().to_string()
        });

        let mut report_bytes = serde_json::to_vec_pretty(&report)?;
        report_bytes.push(b'\n');
        fs::write(&report_path, report_bytes)?;

        eprintln!("opening-school-gate: COMPLETE");
        eprintln!(
            "opening-school-gate: output BIN SHA-256 {}",
            output_sha256
        );
        eprintln!(
            "opening-school-gate: {} changed raw sectors",
            changed_lbas.len()
        );
        eprintln!(
            "opening-school-gate: output CUE {}",
            output_cue.display()
        );
        eprintln!(
            "opening-school-gate: preview {}",
            preview_path.display()
        );

        Ok(())
    }
}

'@

$InjectedSource =
    $OriginalSource.TrimEnd() + [Environment]::NewLine + $RustPatch + [Environment]::NewLine

$OldFontEnv = $env:JG_OPENING_SCHOOL_GATE_FONT
$BuildSucceeded = $false

try {
    [System.IO.File]::WriteAllText(
        $DiarySceneSource,
        $InjectedSource,
        [System.Text.UTF8Encoding]::new($false)
    )

    $env:JG_OPENING_SCHOOL_GATE_FONT = $FontPath

    Write-Host ""
    Write-Host "Building corrected opening SCHOOL GATE layer..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_opening_school_gate_patch_v3",
            "--", "--nocapture"
        )
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
    [System.IO.File]::WriteAllText(
        $DiarySceneSource,
        $OriginalSource,
        [System.Text.UTF8Encoding]::new($false)
    )

    if ($null -eq $OldFontEnv) {
        Remove-Item Env:JG_OPENING_SCHOOL_GATE_FONT -ErrorAction SilentlyContinue
    }
    else {
        $env:JG_OPENING_SCHOOL_GATE_FONT = $OldFontEnv
    }
}

if (-not $BuildSucceeded) {
    Fail "Opening SCHOOL GATE build did not complete."
}
if (-not (Test-Path $OutputBin)) {
    Fail "Build reported success but output BIN is missing."
}
if (-not (Test-Path $OutputCue)) {
    Fail "Build reported success but output CUE is missing."
}
if (-not (Test-Path $ReportPath)) {
    Fail "Build reported success but verification report is missing."
}
if (-not (Test-Path $PreviewPath)) {
    Fail "Build reported success but preview PNG is missing."
}

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "Final PowerShell SHA-256 does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "CORRECTED OPENING SCHOOL GATE BUILD COMPLETE" -ForegroundColor Green
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
Write-Host "This rebuild starts from the clean ad068a base; the earlier member-57 experiment is NOT carried forward." -ForegroundColor Green

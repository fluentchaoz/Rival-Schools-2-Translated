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

$OutputDir = Join-Path $Upstream "work\english-road-to-batsu-dynamic-date-pretty-v2\build"
$OutputBin = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2.bin"
$OutputCue = Join-Path $OutputDir "justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2.cue"
$ReportPath = Join-Path $OutputDir "dynamic-date-pretty-v2-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - PRETTY DYNAMIC ENGLISH DATE v2" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream directory beside this script." }
if (-not (Test-Path $SourcePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $BaseBin)) { Fail "Missing clean SCHOOL GATE fit BIN." }

$BaseHash = (Get-FileHash $BaseBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Base BIN SHA-256: {0}" -f $BaseHash)
if ($BaseHash -ne $ExpectedBaseHash) {
    Fail "Base BIN is not the exact clean a2e158... SCHOOL GATE fit build. Nothing was changed."
}
Write-Host "Base hash verified." -ForegroundColor Green

$Marker = "// ENGLISH_PROJECT_PRETTY_DYNAMIC_DATE_V2"
$OriginalSource = [System.IO.File]::ReadAllText($SourcePath)
if ($OriginalSource.Contains($Marker)) {
    Fail "A stale pretty-date v2 injection is already present in source_disc.rs."
}

$Rust = @'

// ENGLISH_PROJECT_PRETTY_DYNAMIC_DATE_V2
#[cfg(test)]
mod english_pretty_dynamic_date_v2 {
    use std::collections::BTreeMap;
    use std::fs;
    use std::path::Path;

    use anyhow::{Context, Result, ensure};
    use serde_json::json;

    use crate::tim::{Cell, read_indexed_cell_in_prefix, write_indexed_cell_in_prefix};

    const INPUT_HASH: &str =
        "a2e1587b828d5508a5dc99e4e64020d0a16fb4a8d0a569d3e8ddffccff0d98d1";
    const MGAME_SHA256: &str =
        "887c7c1775db5a18aed19661a08d109a5f35c54303259b21c7d6560ef1a3baba";
    const MGCOCK_STORED_SHA256: &str =
        "241d3ba8b25aef281c932f9bd64c0ffb84693abf72ad7b1d5cde852d4b655285";
    const MGCOCK_DECODED_SHA256: &str =
        "bc81dda96d98a4ed06b37db9415636430db630d13217d2275059bb306d9fb655";

    // Native fixed date sprites:
    //   月, 日, (, )
    const ORIGINAL_FIXED_UV: [u8; 8] = [
        160, 0,
        0, 24,
        16, 24,
        32, 24,
    ];

    // Production layout:
    //   "/" comes from the former right-paren calendar cell.
    //   日 suffix + both parentheses point at an existing transparent source
    //   cell. We DO NOT write into that transparent cell.
    //
    // Visible format therefore becomes:
    //     4/1 THU
    const PRETTY_FIXED_UV: [u8; 8] = [
        32, 24,
        176, 192,
        176, 192,
        176, 192,
    ];

    // Weekday consumer stays entirely native:
    // SUN=(0,24), MON=(160,0), Tue..Sat=(176..240,0)
    const ORIGINAL_WEEKDAY_UV: [u8; 14] = [
        0, 24,
        160, 0,
        176, 0,
        192, 0,
        208, 0,
        224, 0,
        240, 0,
    ];

    const SUN_CELL: Cell = Cell { x: 0, y: 24, width: 16, height: 24 };
    const MON_CELL: Cell = Cell { x: 160, y: 0, width: 16, height: 24 };
    const TUE_CELL: Cell = Cell { x: 176, y: 0, width: 16, height: 24 };
    const WED_CELL: Cell = Cell { x: 192, y: 0, width: 16, height: 24 };
    const THU_CELL: Cell = Cell { x: 208, y: 0, width: 16, height: 24 };
    const FRI_CELL: Cell = Cell { x: 224, y: 0, width: 16, height: 24 };
    const SAT_CELL: Cell = Cell { x: 240, y: 0, width: 16, height: 24 };

    const SLASH_CELL: Cell = Cell { x: 32, y: 24, width: 16, height: 24 };
    const TRANSPARENT_CELL: Cell = Cell { x: 176, y: 192, width: 16, height: 24 };

    const SUN_HASH: &str =
        "795b265fe0b306e9acf095d7ea178b86931c8b2f9a776df13fb4cb698bb7dc85";
    const MON_HASH: &str =
        "72044f0fba7f9619e069219b58c60039508a2d15169a7da66bfc4fc5c873587d";
    const TUE_HASH: &str =
        "6230067be3f2d0a8bf3ce04c67beb14cec7463cf1239e8089e4f9be9257b5175";
    const WED_HASH: &str =
        "511086e8e68a2155ff3df3f205aa57b5fc0a28456eb6ca1fb896f45bcc1fdb0f";
    const THU_HASH: &str =
        "0cdb5adea141f7f3102575ab0ee9c33ea811bb183cccf2d2af8d2d35222c20b8";
    const FRI_HASH: &str =
        "a7d9b5ee3f5a9b804d8057bffd471a256d693ecfcdbe03a0446c92cac0f371c3";
    const SAT_HASH: &str =
        "41f7730ea585e0d5356666639c344f411e36cd4cdfab59525ffdeb403c352bc5";
    const RIGHT_PAREN_HASH: &str =
        "3107128457dedcc8ad21987dd0c6f59881d7757382c8b6a0c0dfeadd0ae37744";

    fn verify_cell(decoded: &[u8], cell: Cell, expected: &str, name: &str) -> Result<()> {
        let pixels = read_indexed_cell_in_prefix(decoded, 0, cell)?;
        ensure!(
            crate::pipeline::sha256_bytes(&pixels) == expected,
            "{name} source cell changed"
        );
        Ok(())
    }

    fn ink_indices(source: &[u8]) -> (u8, u8) {
        let mut counts = BTreeMap::<u8, usize>::new();
        for &pixel in source {
            if pixel != 0 {
                *counts.entry(pixel).or_default() += 1;
            }
        }
        let mut ranked = counts.into_iter().collect::<Vec<_>>();
        ranked.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
        let fill = ranked.first().map(|(v, _)| *v).unwrap_or(15);
        let outline = ranked.get(1).map(|(v, _)| *v).unwrap_or(fill);
        (fill, outline)
    }

    // Compact 4x5 pixel letters. At 1x horizontal and 3x vertical,
    // three letters occupy 14x15 before outline: large and crisp inside 16x24.
    fn glyph(ch: char) -> [u8; 5] {
        match ch {
            'A' => [0b0110, 0b1001, 0b1111, 0b1001, 0b1001],
            'D' => [0b1110, 0b1001, 0b1001, 0b1001, 0b1110],
            'E' => [0b1111, 0b1000, 0b1110, 0b1000, 0b1111],
            'F' => [0b1111, 0b1000, 0b1110, 0b1000, 0b1000],
            'H' => [0b1001, 0b1001, 0b1111, 0b1001, 0b1001],
            'I' => [0b1111, 0b0110, 0b0110, 0b0110, 0b1111],
            'M' => [0b1001, 0b1111, 0b1111, 0b1001, 0b1001],
            'N' => [0b1001, 0b1101, 0b1011, 0b1001, 0b1001],
            'O' => [0b0110, 0b1001, 0b1001, 0b1001, 0b0110],
            'R' => [0b1110, 0b1001, 0b1110, 0b1010, 0b1001],
            'S' => [0b1111, 0b1000, 0b1111, 0b0001, 0b1111],
            'T' => [0b1111, 0b0110, 0b0110, 0b0110, 0b0110],
            'U' => [0b1001, 0b1001, 0b1001, 0b1001, 0b1111],
            'W' => [0b1001, 0b1001, 0b1011, 0b1111, 0b1001],
            _ => panic!("unsupported pretty calendar glyph {ch:?}"),
        }
    }

    fn draw_weekday(source: &[u8], text: &str) -> Vec<u8> {
        let (fill, outline) = ink_indices(source);
        let mut pixels = vec![0u8; 16 * 24];

        let chars = text.chars().collect::<Vec<_>>();
        assert_eq!(chars.len(), 3);

        let glyph_w = 4usize;
        let gap = 1usize;
        let scale_y = 3usize;
        let text_w = chars.len() * glyph_w + (chars.len() - 1) * gap; // 14
        let text_h = 5 * scale_y; // 15
        let start_x = (16 - text_w) / 2; // 1
        let start_y = (24 - text_h) / 2; // 4

        let paint = |pixels: &mut [u8], dx: isize, dy: isize, ink: u8| {
            for (i, ch) in chars.iter().copied().enumerate() {
                let rows = glyph(ch);
                let base_x = start_x + i * (glyph_w + gap);
                for (row, bits) in rows.into_iter().enumerate() {
                    for col in 0..glyph_w {
                        if bits & (1 << (glyph_w - 1 - col)) == 0 {
                            continue;
                        }
                        for sy in 0..scale_y {
                            let x = base_x as isize + col as isize + dx;
                            let y = start_y as isize + (row * scale_y + sy) as isize + dy;
                            if x >= 0 && y >= 0 && x < 16 && y < 24 {
                                pixels[y as usize * 16 + x as usize] = ink;
                            }
                        }
                    }
                }
            }
        };

        if outline != fill {
            for (dx, dy) in [
                (-1, 0), (1, 0), (0, -1), (0, 1),
            ] {
                paint(&mut pixels, dx, dy, outline);
            }
        }
        paint(&mut pixels, 0, 0, fill);
        pixels
    }

    fn draw_slash(source: &[u8]) -> Vec<u8> {
        let (fill, outline) = ink_indices(source);
        let mut pixels = vec![0u8; 16 * 24];

        // Tall, clean slash matched to the native date cell height.
        let mut points = Vec::<(isize, isize)>::new();
        for y in 3isize..21isize {
            // x falls from ~11 to ~4.
            let x = 11 - ((y - 3) * 7 / 17);
            points.push((x, y));
            points.push((x + 1, y));
        }

        if outline != fill {
            for &(x, y) in &points {
                for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                    let xx = x + dx;
                    let yy = y + dy;
                    if xx >= 0 && yy >= 0 && xx < 16 && yy < 24 {
                        pixels[yy as usize * 16 + xx as usize] = outline;
                    }
                }
            }
        }
        for (x, y) in points {
            if x >= 0 && y >= 0 && x < 16 && y < 24 {
                pixels[y as usize * 16 + x as usize] = fill;
            }
        }
        pixels
    }

    #[test]
    fn english_pretty_dynamic_date_v2() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("justice-gakuen2-pretty-date-large-stack".to_string())
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

        let output_root = root.join("work/english-road-to-batsu-dynamic-date-pretty-v2");
        let build_dir = output_root.join("build");
        let output_bin =
            build_dir.join("justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2.bin");
        let output_cue =
            build_dir.join("justice-gakuen2-road-to-batsu-dynamic-date-pretty-v2.cue");
        let report_path =
            build_dir.join("dynamic-date-pretty-v2-report.json");

        ensure!(input.is_file(), "clean SCHOOL GATE fit BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "clean SCHOOL GATE fit BIN hash changed"
        );

        if output_root.exists() {
            fs::remove_dir_all(&output_root)?;
        }
        fs::create_dir_all(&build_dir)?;

        eprintln!("pretty-date: verifying clean MGAME + MGCOCK");

        let (_, source_mgame) =
            crate::disc::rebuild::read_record(&input, "DAT1/MGAME.BIN")?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_mgame) == MGAME_SHA256,
            "MGAME.BIN source changed"
        );
        ensure!(
            source_mgame.get(0x1bd0..0x1bd8) == Some(ORIGINAL_FIXED_UV.as_slice()),
            "native fixed date UV table changed"
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

        verify_cell(&decoded, SUN_CELL, SUN_HASH, "Sunday/day")?;
        verify_cell(&decoded, MON_CELL, MON_HASH, "Monday/month")?;
        verify_cell(&decoded, TUE_CELL, TUE_HASH, "Tuesday")?;
        verify_cell(&decoded, WED_CELL, WED_HASH, "Wednesday")?;
        verify_cell(&decoded, THU_CELL, THU_HASH, "Thursday")?;
        verify_cell(&decoded, FRI_CELL, FRI_HASH, "Friday")?;
        verify_cell(&decoded, SAT_CELL, SAT_HASH, "Saturday")?;
        verify_cell(&decoded, SLASH_CELL, RIGHT_PAREN_HASH, "right parenthesis")?;

        let transparent_before =
            read_indexed_cell_in_prefix(&decoded, 0, TRANSPARENT_CELL)?;
        ensure!(
            transparent_before.iter().all(|p| *p == transparent_before[0]),
            "selected transparent source cell is no longer uniform"
        );

        // Native decimal digits must remain byte-identical.
        let digit_hashes_before = (0..10usize)
            .map(|digit| {
                let cell = Cell { x: digit * 16, y: 0, width: 16, height: 24 };
                Ok(crate::pipeline::sha256_bytes(
                    &read_indexed_cell_in_prefix(&decoded, 0, cell)?
                ))
            })
            .collect::<Result<Vec<_>>>()?;

        let weekday_specs = [
            ("SUN", SUN_CELL),
            ("MON", MON_CELL),
            ("TUE", TUE_CELL),
            ("WED", WED_CELL),
            ("THU", THU_CELL),
            ("FRI", FRI_CELL),
            ("SAT", SAT_CELL),
        ];

        for (name, cell) in weekday_specs {
            let source_pixels = read_indexed_cell_in_prefix(&decoded, 0, cell)?;
            let pretty = draw_weekday(&source_pixels, name);
            write_indexed_cell_in_prefix(&mut decoded, 0, cell, &pretty)?;
            eprintln!(
                "pretty-date: rendered {name} in native weekday slot UV=({}, {})",
                cell.x, cell.y
            );
        }

        let slash_source =
            read_indexed_cell_in_prefix(&decoded, 0, SLASH_CELL)?;
        let slash = draw_slash(&slash_source);
        write_indexed_cell_in_prefix(&mut decoded, 0, SLASH_CELL, &slash)?;
        eprintln!(
            "pretty-date: rendered slash in former right-parenthesis slot UV=(32, 24)"
        );

        // Prove the transparent cell used as a sink was NOT modified.
        let transparent_after =
            read_indexed_cell_in_prefix(&decoded, 0, TRANSPARENT_CELL)?;
        ensure!(
            transparent_after == transparent_before,
            "transparent sink cell was modified"
        );

        // Prove all native decimal digit art stayed untouched.
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

        let mut patched_mgame = source_mgame.clone();
        patched_mgame[0x1bd0..0x1bd8].copy_from_slice(&PRETTY_FIXED_UV);

        // Weekday UVs remain EXACTLY native. This is the important isolation
        // change versus the proof-of-concept build.
        ensure!(
            patched_mgame[0x1be4..0x1bf2] == source_mgame[0x1be4..0x1bf2],
            "weekday UV table changed"
        );
        ensure!(
            source_mgame.iter().zip(&patched_mgame).enumerate().all(|(i, (a, b))| {
                a == b || (0x1bd0..0x1bd8).contains(&i)
            }),
            "MGAME changed outside fixed date UV table"
        );

        let source_profile =
            crate::paged_compression::source_paged_compression_profile(&source_stored)?;
        let reencoded =
            crate::paged_compression::compress_page_safe_image(&decoded, source_profile)?;
        ensure!(
            crate::compression::decompress(&reencoded, false)? == decoded,
            "MGCOCK compression roundtrip changed decoded pixels"
        );
        ensure!(
            reencoded.len() <= source_stored.len(),
            "pretty English MGCOCK exceeds fixed source record"
        );
        let unpadded_mgcock_size = reencoded.len();
        let mut patched_stored = reencoded;
        patched_stored.resize(source_stored.len(), 0);
        ensure!(
            crate::compression::decompress(&patched_stored, true)? == decoded,
            "padded pretty MGCOCK changed decoded pixels"
        );

        eprintln!("pretty-date: rebuilding exactly MGAME.BIN + MGCOCK.TIZ");

        let replacements = [
            crate::disc::rebuild::FixedRecordReplacement {
                path: "DAT1/MGAME.BIN",
                data: &patched_mgame,
            },
            crate::disc::rebuild::FixedRecordReplacement {
                path: "DAT2/MGCOCK.TIZ",
                data: &patched_stored,
            },
        ];

        let rebuilt =
            crate::disc::rebuild::copy_and_replace_records(&input, &output_bin, &replacements)?;
        ensure!(
            rebuilt.len() == 2,
            "disc rebuild did not replace exactly two records"
        );

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

        ensure!(
            fs::metadata(&input)?.len() == fs::metadata(&output_bin)?.len(),
            "disc image length changed"
        );

        let (changed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(&input, &output_bin)?;
        ensure!(!changed_lbas.is_empty(), "pretty-date patch changed no sectors");
        ensure!(
            changed_lbas.iter().all(|lba| {
                rebuilt.iter().any(|record| record.target_lbas.contains(lba))
            }),
            "pretty-date patch changed sectors outside MGAME/MGCOCK"
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
            "kind": "Justice Gakuen 2 pretty dynamic English date v2",
            "input_bin_sha256": INPUT_HASH,
            "output_bin_sha256": output_sha256,
            "output_cue": output_cue.display().to_string(),
            "visible_format": "M/D DDD",
            "opening_example": "4/1 THU",
            "dynamic_month": true,
            "dynamic_day": true,
            "dynamic_weekday": true,
            "month_state": "0x801f1855",
            "day_state": "0x801f1856",
            "weekday_state": "0x801f1857",
            "fixed_uv_table": {
                "offset": "MGAME +0x01bd0",
                "source": ORIGINAL_FIXED_UV,
                "patched": PRETTY_FIXED_UV
            },
            "weekday_uv_table_unchanged": true,
            "weekday_uv_table": ORIGINAL_WEEKDAY_UV,
            "weekday_slots": {
                "SUN": [0,24],
                "MON": [160,0],
                "TUE": [176,0],
                "WED": [192,0],
                "THU": [208,0],
                "FRI": [224,0],
                "SAT": [240,0]
            },
            "slash_cell": [32,24],
            "transparent_sink_cell": [176,192],
            "transparent_sink_modified": false,
            "native_digits_preserved": true,
            "parentheses_intentionally_hidden": true,
            "mgame_source_sha256": MGAME_SHA256,
            "mgame_patched_sha256": crate::pipeline::sha256_bytes(&patched_mgame),
            "mgcock_source_stored_sha256": MGCOCK_STORED_SHA256,
            "mgcock_source_decoded_sha256": MGCOCK_DECODED_SHA256,
            "mgcock_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
            "mgcock_patched_decoded_sha256": crate::pipeline::sha256_bytes(&decoded),
            "mgcock_unpadded_size": unpadded_mgcock_size,
            "changed_sector_count": changed_lbas.len(),
            "readback_verified": true
        });

        let mut bytes = serde_json::to_vec_pretty(&report)?;
        bytes.push(b'\n');
        fs::write(&report_path, bytes)?;

        eprintln!("pretty-date: COMPLETE");
        eprintln!("pretty-date: output BIN SHA-256 {}", output_sha256);
        eprintln!("pretty-date: changed raw sectors {}", changed_lbas.len());
        eprintln!("pretty-date: CUE {}", output_cue.display());
        eprintln!("pretty-date: expected opening text 4/1 THU");

        Ok(())
    }
}

'@

$Injected =
    $OriginalSource.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine
$Succeeded = $false

try {
    [System.IO.File]::WriteAllText(
        $SourcePath,
        $Injected,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "Building isolated, readable dynamic English calendar..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_pretty_dynamic_date_v2",
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
}

if (-not $Succeeded) { Fail "Pretty dynamic date build did not complete." }
if (-not (Test-Path $OutputBin)) { Fail "Output BIN is missing." }
if (-not (Test-Path $OutputCue)) { Fail "Output CUE is missing." }
if (-not (Test-Path $ReportPath)) { Fail "Verification report is missing." }

$Report = Get-Content $ReportPath -Raw | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA-256 does not match Rust verification report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "PRETTY DYNAMIC ENGLISH DATE v2 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Cyan
Write-Host $OutputCue
Write-Host ""
Write-Host "EXPECTED OPENING DATE:" -ForegroundColor Cyan
Write-Host "4/1 THU"
Write-Host ""
Write-Host "This build starts from the clean a2e158... base." -ForegroundColor Green
Write-Host "It does NOT modify the shared transparent HUD cell." -ForegroundColor Green
Write-Host "Weekdays stay in their native calendar slots." -ForegroundColor Green

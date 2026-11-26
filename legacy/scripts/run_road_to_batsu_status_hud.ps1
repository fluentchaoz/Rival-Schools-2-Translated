param()

$ErrorActionPreference = "Stop"

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
$ProbePath = Join-Path $Upstream "src\source_disc.rs"

$InputBin = Join-Path $Upstream "work\english-road-to-batsu-mgk04\build\justice-gakuen2-road-to-batsu-mgk04.bin"
$ExpectedInputHash = "09165121e7141830c8c3027ca2de8c08e82cd624627092d4efde2b8d5fcd453b"

if (-not (Test-Path $ProbePath)) { Fail "Missing upstream\src\source_disc.rs." }
if (-not (Test-Path $InputBin)) { Fail "Missing the successful MGK04 v5 BIN." }

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Input BIN is not the exact successful MGK04 v5 build."
}

$Marker = "fn english_road_to_batsu_status_hud_patch()"
$Text = [System.IO.File]::ReadAllText($ProbePath)

if (-not $Text.Contains($Marker)) {
$Rust = @'

#[cfg(test)]
mod english_road_to_batsu_status_hud {
    use std::collections::BTreeMap;
    use std::fs;
    use std::io::{Read, Seek, SeekFrom};
    use std::path::Path;

    use anyhow::{Result, ensure};

    use super::*;

    const INPUT_HASH: &str =
        "09165121e7141830c8c3027ca2de8c08e82cd624627092d4efde2b8d5fcd453b";
    const TARGET_PATH: &str = "DAT2/MGCOCK.TIZ";
    const SOURCE_STORED_SHA256: &str =
        "a3af55cefe56dde6e068ca2c079fe4c97df00dadc59b35138ce2d20a9e4f3570";

    const LABELS: [(&str, crate::tim::Cell); 6] = [
        ("ATK",  crate::tim::Cell { x:   0, y: 48, width: 48, height: 16 }),
        ("DEF",  crate::tim::Cell { x:  48, y: 48, width: 48, height: 16 }),
        ("STAM", crate::tim::Cell { x:  96, y: 48, width: 48, height: 16 }),
        ("GUTS", crate::tim::Cell { x: 144, y: 48, width: 48, height: 16 }),
        ("POT",  crate::tim::Cell { x:  80, y: 32, width: 48, height: 16 }),
        ("INT",  crate::tim::Cell { x: 128, y: 32, width: 48, height: 16 }),
    ];

    fn glyph(ch: char) -> [u8; 7] {
        match ch {
            'A' => [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
            'B' => [0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110],
            'C' => [0b01111,0b10000,0b10000,0b10000,0b10000,0b10000,0b01111],
            'D' => [0b11110,0b10001,0b10001,0b10001,0b10001,0b10001,0b11110],
            'E' => [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
            'F' => [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000],
            'G' => [0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01110],
            'H' => [0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
            'I' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b11111],
            'J' => [0b00111,0b00010,0b00010,0b00010,0b10010,0b10010,0b01100],
            'K' => [0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001],
            'L' => [0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111],
            'M' => [0b10001,0b11011,0b10101,0b10101,0b10001,0b10001,0b10001],
            'N' => [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
            'O' => [0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
            'P' => [0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000],
            'Q' => [0b01110,0b10001,0b10001,0b10001,0b10101,0b10010,0b01101],
            'R' => [0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
            'S' => [0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110],
            'T' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
            'U' => [0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
            'V' => [0b10001,0b10001,0b10001,0b10001,0b10001,0b01010,0b00100],
            'W' => [0b10001,0b10001,0b10001,0b10101,0b10101,0b11011,0b10001],
            'X' => [0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001],
            'Y' => [0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100],
            'Z' => [0b11111,0b00001,0b00010,0b00100,0b01000,0b10000,0b11111],
            _ => panic!("unsupported status HUD glyph {ch:?}"),
        }
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
        let primary = ranked.first().map(|(v, _)| *v).unwrap_or(14);
        let secondary = ranked.get(1).map(|(v, _)| *v).unwrap_or(primary);
        (primary, secondary)
    }

    fn draw_label(width: usize, height: usize, text: &str, fill: u8, outline: u8) -> Vec<u8> {
        let chars = text.chars().collect::<Vec<_>>();
        let scale = 2usize;
        let text_width = chars.len() * 5 * scale
            + chars.len().saturating_sub(1) * scale;
        assert!(text_width <= width, "{text} does not fit {width}px status cell");
        let text_height = 7 * scale;
        assert!(text_height <= height);
        let start_x = (width - text_width) / 2;
        let start_y = (height - text_height) / 2;
        let mut pixels = vec![0u8; width * height];

        let paint = |pixels: &mut [u8], dx: isize, dy: isize, ink: u8| {
            for (i, ch) in chars.iter().copied().enumerate() {
                let rows = glyph(ch);
                let base_x = start_x + i * 6 * scale;
                for (row, bits) in rows.into_iter().enumerate() {
                    for col in 0..5usize {
                        if bits & (1 << (4 - col)) == 0 {
                            continue;
                        }
                        for sy in 0..scale {
                            for sx in 0..scale {
                                let x = base_x as isize + (col * scale + sx) as isize + dx;
                                let y = start_y as isize + (row * scale + sy) as isize + dy;
                                if x >= 0 && y >= 0 && (x as usize) < width && (y as usize) < height {
                                    pixels[y as usize * width + x as usize] = ink;
                                }
                            }
                        }
                    }
                }
            }
        };

        if outline != fill {
            for (dx, dy) in [(-1,0),(1,0),(0,-1),(0,1)] {
                paint(&mut pixels, dx, dy, outline);
            }
        }
        paint(&mut pixels, 0, 0, fill);
        pixels
    }

    #[test]
    fn english_road_to_batsu_status_hud_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-road-to-batsu-mgk04/build/justice-gakuen2-road-to-batsu-mgk04.bin",
        );
        ensure!(input.is_file(), "MGK04 v5 input BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "MGK04 v5 input BIN hash changed"
        );

        let (_, stored) = crate::disc::rebuild::read_record(&input, TARGET_PATH)?;
        ensure!(
            crate::pipeline::sha256_bytes(&stored) == SOURCE_STORED_SHA256,
            "MGCOCK.TIZ was already modified before the HUD patch"
        );

        let mut decoded = crate::compression::decompress(&stored, false)?;
        let tim = crate::tim::parse_4bpp_prefix(&decoded)?;
        ensure!(
            tim.pixel_width() == 1024 && tim.image_height == 256,
            "unexpected MGCOCK TIM geometry"
        );

        for (text, cell) in LABELS {
            let source_pixels =
                crate::tim::read_indexed_cell_in_prefix(&decoded, 0, cell)?;
            let (fill, outline) = ink_indices(&source_pixels);
            let replacement = draw_label(cell.width, cell.height, text, fill, outline);
            crate::tim::write_indexed_cell_in_prefix(
                &mut decoded,
                0,
                cell,
                &replacement,
            )?;
            println!(
                "HUD_LABEL={} CELL=({},{} {}x{}) FILL={} OUTLINE={}",
                text, cell.x, cell.y, cell.width, cell.height, fill, outline
            );
        }

        let source_profile =
            crate::paged_compression::source_paged_compression_profile(&stored)?;
        let reencoded =
            crate::paged_compression::compress_page_safe_image(&decoded, source_profile)?;
        ensure!(
            crate::compression::decompress(&reencoded, false)? == decoded,
            "MGCOCK recompression roundtrip changed decoded pixels"
        );
        ensure!(
            reencoded.len() <= stored.len(),
            "English MGCOCK exceeds original fixed record"
        );
        let mut padded = reencoded;
        padded.resize(stored.len(), 0);
        ensure!(
            crate::compression::decompress(&padded, true)? == decoded,
            "padded English MGCOCK changed decoded pixels"
        );

        let output = root.join(
            "work/english-road-to-batsu-mgk04/build/justice-gakuen2-road-to-batsu-hud.bin",
        );
        if output.exists() {
            fs::remove_file(&output)?;
        }

        let rebuilt = crate::disc::rebuild::copy_and_replace_record(
            &input,
            &output,
            TARGET_PATH,
            &padded,
        )?;
        ensure!(
            rebuilt.changed_lbas.iter().all(|lba| rebuilt.target_lbas.contains(lba)),
            "HUD patch changed sectors outside MGCOCK.TIZ"
        );

        let (_, readback) = crate::disc::rebuild::read_record(&output, TARGET_PATH)?;
        ensure!(readback == padded, "MGCOCK readback differs from rebuilt record");

        let (changed, output_sha) =
            crate::disc::rebuild::compare_and_hash_images(&input, &output)?;
        ensure!(changed == rebuilt.changed_lbas);

        let mut file = fs::File::open(&output)?;
        for &lba in &changed {
            let mut sector = [0u8; crate::disc::RAW_SECTOR_SIZE];
            file.seek(SeekFrom::Start(
                u64::from(lba) * crate::disc::RAW_SECTOR_SIZE as u64,
            ))?;
            file.read_exact(&mut sector)?;
            ensure!(
                crate::disc::mode2::verify(&sector),
                "rebuilt MGCOCK raw sector {lba} failed Mode-2 verification"
            );
        }

        println!("HUD_CHANGED_LBAS={changed:?}");
        println!("HUD_OUTPUT_SHA256={output_sha}");
        Ok(())
    }
}
'@

    [System.IO.File]::AppendAllText(
        $ProbePath,
        $Rust,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

Write-Host ""
Write-Host "Justice Gakuen English Project - Road to Batsu: Status HUD" -ForegroundColor Cyan
Write-Host "Translating persistent School Life stat labels:" -ForegroundColor Yellow
Write-Host "  ATK / DEF / STAM / GUTS / POT / INT"
Write-Host ""
Write-Host "[1/3] Building MGCOCK status HUD patch..."

Push-Location $Upstream
try {
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_road_to_batsu_status_hud::english_road_to_batsu_status_hud_patch",
        "--", "--exact", "--nocapture"
    )

    $OutputBin = Join-Path $Upstream "work\english-road-to-batsu-mgk04\build\justice-gakuen2-road-to-batsu-hud.bin"
    if (-not (Test-Path $OutputBin)) {
        Fail "HUD test passed but the output BIN was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Writing matching CUE..."
    $OutputCue = Join-Path $Upstream "work\english-road-to-batsu-mgk04\build\justice-gakuen2-road-to-batsu-hud.cue"
    @'
FILE "justice-gakuen2-road-to-batsu-hud.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $OutputCue

    Write-Host ""
    Write-Host "[3/3] Hashing final build..."
    $OutputHash = (Get-FileHash -Algorithm SHA256 $OutputBin).Hash.ToLower()
    Write-Host ("Output SHA-256: {0}" -f $OutputHash)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "ROAD TO BATSU - STATUS HUD ENGLISH BUILD COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This pass changes only the six persistent stat-label cells in DAT2/MGCOCK.TIZ." -ForegroundColor Cyan
    Write-Host "Date formatting and the School Gate location tag are the next HUD surfaces." -ForegroundColor Cyan
}
finally {
    Pop-Location
}

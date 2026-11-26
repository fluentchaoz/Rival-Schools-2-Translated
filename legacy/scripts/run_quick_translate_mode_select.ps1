param(
    [Parameter(Mandatory=$false)]
    [string]$InputBin = ""
)

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
$ExpectedV7Hash = "d9b1a57313e3714980f4c618aeffb975bb00286bdcdcab1a4a9a0fb24ab850f2"

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder beside this script."
}

if ([string]::IsNullOrWhiteSpace($InputBin)) {
    $InputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1.bin"
}
if (-not (Test-Path $InputBin)) {
    Fail "Could not find the v7 playable BIN. Pass -InputBin if you moved it."
}

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedV7Hash) {
    Fail "Input BIN is not the exact successful v7 Batsu prototype."
}

$ProbePath = Join-Path $Upstream "src\source_disc.rs"
$Marker = "fn english_quick_mode_select_menu_patch()"

Push-Location $Upstream
try {
    $SourceText = [System.IO.File]::ReadAllText($ProbePath)
    if (-not $SourceText.Contains($Marker)) {
        $Probe = @'

#[cfg(test)]
mod english_quick_mode_select_menu {
    use super::*;
    use std::collections::BTreeMap;
    use std::io::{Read, Seek, SeekFrom};
    use std::path::Path;

    const MENU_PATH: &str = "DAT2/MENU.BIZ";
    const OVERLAY_PATH: &str = "DAT1/MODESEL.BIN";
    const ATLAS_TIM_OFFSET: usize = 0x22800;
    const DESCRIPTION_TIM_FIRST_OFFSET: usize = 0x4b800;
    const DESCRIPTION_TIM_STRIDE: usize = 0x2800;
    const PANEL_INDEX_BY_MODE_INDEX: [usize; 14] =
        [6, 0, 1, 10, 8, 9, 7, 13, 2, 11, 12, 5, 4, 3];

    const LIST_DESCRIPTOR_FIRST_OFFSET: usize = 0x01ac;
    const LIST_DESCRIPTOR_STRIDE: usize = 0x18;
    const DETAIL_COORDINATE_FIRST_OFFSET: usize = 0x0508;
    const DETAIL_COORDINATE_STRIDE: usize = 6;

    const LABELS: [&str; 14] = [
        "SCHOOL LIFE 2",
        "SOLO PLAY",
        "VERSUS",
        "LEAGUE",
        "TEAM BATTLE",
        "TOURNAMENT",
        "CO-OP",
        "TRAINING",
        "SKILL 99",
        "GORIN FEST",
        "EDIT",
        "BONUS",
        "RECORDS",
        "OPTIONS",
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
            '0' => [0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110],
            '1' => [0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110],
            '2' => [0b01110,0b10001,0b00001,0b00010,0b00100,0b01000,0b11111],
            '3' => [0b11110,0b00001,0b00001,0b01110,0b00001,0b00001,0b11110],
            '4' => [0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010],
            '5' => [0b11111,0b10000,0b10000,0b11110,0b00001,0b00001,0b11110],
            '6' => [0b01110,0b10000,0b10000,0b11110,0b10001,0b10001,0b01110],
            '7' => [0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000],
            '8' => [0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110],
            '9' => [0b01110,0b10001,0b10001,0b01111,0b00001,0b00001,0b01110],
            '-' => [0,0,0,0b11111,0,0,0],
            ' ' => [0,0,0,0,0,0,0],
            _ => panic!("unsupported quick-menu glyph {ch:?}"),
        }
    }

    fn read_u16(data: &[u8], offset: usize) -> u16 {
        u16::from_le_bytes([data[offset], data[offset + 1]])
    }

    fn list_cell(overlay: &[u8], panel_index: usize) -> crate::tim::Cell {
        let offset = LIST_DESCRIPTOR_FIRST_OFFSET + panel_index * LIST_DESCRIPTOR_STRIDE;
        let page_x = match read_u16(overlay, offset + 4) {
            0x0240 => 256,
            0x0280 => 512,
            value => panic!("unknown list texture page 0x{value:04x}"),
        };
        crate::tim::Cell {
            x: page_x + usize::from(read_u16(overlay, offset + 12)),
            y: usize::from(read_u16(overlay, offset + 14)),
            width: usize::from(read_u16(overlay, offset + 16)),
            height: usize::from(read_u16(overlay, offset + 18)),
        }
    }

    fn detail_cell(overlay: &[u8], panel_index: usize) -> crate::tim::Cell {
        let offset = DETAIL_COORDINATE_FIRST_OFFSET + panel_index * DETAIL_COORDINATE_STRIDE;
        let page_x = match read_u16(overlay, offset) {
            0x02c0 => 768,
            0x0300 => 1024,
            value => panic!("unknown detail texture page 0x{value:04x}"),
        };
        crate::tim::Cell {
            x: page_x + usize::from(read_u16(overlay, offset + 2)),
            y: usize::from(read_u16(overlay, offset + 4)),
            width: 112,
            height: 24,
        }
    }

    fn ink_indices(source: &[u8]) -> (u8, u8) {
        let mut counts = BTreeMap::<u8, usize>::new();
        for &p in source {
            if p != 0 {
                *counts.entry(p).or_default() += 1;
            }
        }
        let mut ranked = counts.into_iter().collect::<Vec<_>>();
        ranked.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
        let primary = ranked.first().map(|(p, _)| *p).unwrap_or(1);
        let secondary = ranked.get(1).map(|(p, _)| *p).unwrap_or(primary);
        (primary, secondary)
    }

    fn draw_text(
        width: usize,
        height: usize,
        text: &str,
        primary: u8,
        shadow: u8,
    ) -> Vec<u8> {
        let chars = text.chars().collect::<Vec<_>>();
        let mut scale = 2usize;
        let needed = |scale: usize| {
            chars.len() * 5 * scale
                + chars.len().saturating_sub(1) * scale
        };
        while scale > 1 && needed(scale) > width.saturating_sub(2) {
            scale -= 1;
        }
        assert!(needed(scale) <= width, "{text} does not fit {width}px");
        let text_width = needed(scale);
        let text_height = 7 * scale;
        let start_x = (width - text_width) / 2;
        let start_y = (height - text_height) / 2;
        let mut pixels = vec![0u8; width * height];

        let paint = |pixels: &mut [u8], dx: usize, dy: usize, ink: u8| {
            for (i, ch) in chars.iter().copied().enumerate() {
                if ch == ' ' {
                    continue;
                }
                let rows = glyph(ch);
                let base_x = start_x + i * 6 * scale + dx;
                for (row, bits) in rows.into_iter().enumerate() {
                    for col in 0..5 {
                        if bits & (1 << (4 - col)) == 0 {
                            continue;
                        }
                        for sy in 0..scale {
                            for sx in 0..scale {
                                let x = base_x + col * scale + sx;
                                let y = start_y + row * scale + sy + dy;
                                if x < width && y < height {
                                    pixels[y * width + x] = ink;
                                }
                            }
                        }
                    }
                }
            }
        };

        if shadow != primary {
            paint(&mut pixels, 1, 1, shadow);
        }
        paint(&mut pixels, 0, 0, primary);
        pixels
    }

    fn draw_description() -> Vec<u8> {
        let width = 176usize;
        let height = 112usize;
        let mut pixels = vec![0u8; width * height];
        let lines = [
            ("SCHOOL LIFE 2", 8usize, 2usize),
            ("CREATE A STUDENT", 39usize, 2usize),
            ("LIVE THE SCHOOL YEAR", 65usize, 1usize),
            ("MAKE FRIENDS & TRAIN", 82usize, 1usize),
            ("SELECT TO BEGIN", 99usize, 1usize),
        ];
        for (text, y, scale) in lines {
            let chars = text.chars().collect::<Vec<_>>();
            let text_width = chars.len() * 5 * scale
                + chars.len().saturating_sub(1) * scale;
            let start_x = (width - text_width) / 2;
            for (i, ch) in chars.into_iter().enumerate() {
                if ch == ' ' {
                    continue;
                }
                let rows = glyph(ch);
                let base_x = start_x + i * 6 * scale;
                for (row, bits) in rows.into_iter().enumerate() {
                    for col in 0..5 {
                        if bits & (1 << (4 - col)) == 0 {
                            continue;
                        }
                        for sy in 0..scale {
                            for sx in 0..scale {
                                let x = base_x + col * scale + sx;
                                let py = y + row * scale + sy;
                                if x < width && py < height {
                                    pixels[py * width + x] = 1;
                                }
                            }
                        }
                    }
                }
            }
        }
        pixels
    }

    #[test]
    fn english_quick_mode_select_menu_patch() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = root.join(
            "work/english-batsu-playable-scene1/build/justice-gakuen2-batsu-english-scene1.bin",
        );
        assert!(input.is_file(), "successful v7 Batsu BIN is missing");

        let (_, menu_stored) =
            crate::disc::rebuild::read_record(&input, MENU_PATH).unwrap();
        let (_, overlay) =
            crate::disc::rebuild::read_record(&input, OVERLAY_PATH).unwrap();
        let mut decoded = crate::compression::decompress(&menu_stored, false).unwrap();

        for mode_index in 0..14 {
            let panel = PANEL_INDEX_BY_MODE_INDEX[mode_index];
            let list = list_cell(&overlay, panel);
            let source_list =
                crate::tim::read_indexed_cell_in_prefix(&decoded, ATLAS_TIM_OFFSET, list)
                    .unwrap();
            let (list_primary, list_shadow) = ink_indices(&source_list);
            let list_pixels =
                draw_text(list.width, list.height, LABELS[mode_index], list_primary, list_shadow);
            crate::tim::write_indexed_cell_in_prefix(
                &mut decoded,
                ATLAS_TIM_OFFSET,
                list,
                &list_pixels,
            )
            .unwrap();

            let detail = detail_cell(&overlay, panel);
            let source_detail =
                crate::tim::read_indexed_cell_in_prefix(&decoded, ATLAS_TIM_OFFSET, detail)
                    .unwrap();
            let (detail_primary, detail_shadow) = ink_indices(&source_detail);
            let detail_pixels =
                draw_text(detail.width, detail.height, LABELS[mode_index], detail_primary, detail_shadow);
            crate::tim::write_indexed_cell_in_prefix(
                &mut decoded,
                ATLAS_TIM_OFFSET,
                detail,
                &detail_pixels,
            )
            .unwrap();
        }

        // Replace Gate-2 proof text with useful School Life instructions.
        let description_offset =
            DESCRIPTION_TIM_FIRST_OFFSET + 6 * DESCRIPTION_TIM_STRIDE;
        let description_cell = crate::tim::Cell {
            x: 0,
            y: 0,
            width: 176,
            height: 112,
        };
        let description = draw_description();
        crate::tim::write_indexed_cell_without_clut_in_prefix(
            &mut decoded,
            description_offset,
            description_cell,
            &description,
        )
        .unwrap();

        let (encoded, _, _) =
            crate::menu_compression::compress_menu_with_source_limits(
                &decoded,
                &menu_stored,
            )
            .unwrap();
        assert!(
            encoded.len() <= menu_stored.len(),
            "quick English MENU.BIZ exceeds original fixed record"
        );
        assert_eq!(&encoded[..4], &menu_stored[..4]);

        let mut padded = encoded;
        padded.resize(menu_stored.len(), 0);
        assert_eq!(
            crate::compression::decompress(&padded, true).unwrap(),
            decoded
        );

        let output = root.join(
            "work/english-batsu-playable-scene1/build/justice-gakuen2-batsu-english-scene1-menus.bin",
        );
        if output.exists() {
            std::fs::remove_file(&output).unwrap();
        }

        let rebuilt =
            crate::disc::rebuild::copy_and_replace_record(
                &input,
                &output,
                MENU_PATH,
                &padded,
            )
            .unwrap();
        assert!(
            rebuilt.changed_lbas.iter().all(|lba| rebuilt.target_lbas.contains(lba)),
            "MENU quick patch changed sectors outside MENU.BIZ"
        );

        let (_, readback) =
            crate::disc::rebuild::read_record(&output, MENU_PATH).unwrap();
        assert_eq!(readback, padded);

        let (all_changed, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(&input, &output).unwrap();
        assert_eq!(all_changed, rebuilt.changed_lbas);

        let mut file = std::fs::File::open(&output).unwrap();
        for &lba in &all_changed {
            let mut sector = [0u8; crate::disc::RAW_SECTOR_SIZE];
            file.seek(SeekFrom::Start(
                u64::from(lba) * crate::disc::RAW_SECTOR_SIZE as u64,
            ))
            .unwrap();
            file.read_exact(&mut sector).unwrap();
            assert!(
                crate::disc::mode2::verify(&sector),
                "quick-menu rebuilt raw sector {lba} failed Mode-2 verification"
            );
        }

        println!("QUICK_MENU_CHANGED_LBAS={:?}", all_changed);
        println!("QUICK_MENU_OUTPUT_SHA256={output_sha256}");
    }
}
'@

        [System.IO.File]::AppendAllText(
            $ProbePath,
            $Probe,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    Write-Host ""
    Write-Host "Justice Gakuen English Project - Quick Mode Select Translation" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1/3] Translating all 14 MODE SELECT labels..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_quick_mode_select_menu::english_quick_mode_select_menu_patch",
        "--", "--exact", "--nocapture"
    )

    $OutputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.bin"
    if (-not (Test-Path $OutputBin)) {
        Fail "Rust menu patch passed but the output BIN was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Writing matching CUE..."
    $OutputCue = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.cue"
    @'
FILE "justice-gakuen2-batsu-english-scene1-menus.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $OutputCue

    Write-Host ""
    Write-Host "[3/3] Hashing final menu-test build..."
    $OutputHash = (Get-FileHash -Algorithm SHA256 $OutputBin).Hash.ToLower()
    Write-Host ("Output SHA-256: {0}" -f $OutputHash)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "QUICK ENGLISH MODE SELECT BUILD COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Translated now:" -ForegroundColor Cyan
    Write-Host "  SCHOOL LIFE 2"
    Write-Host "  SOLO PLAY"
    Write-Host "  VERSUS"
    Write-Host "  LEAGUE"
    Write-Host "  TEAM BATTLE"
    Write-Host "  TOURNAMENT"
    Write-Host "  CO-OP"
    Write-Host "  TRAINING"
    Write-Host "  SKILL 99"
    Write-Host "  GORIN FEST"
    Write-Host "  EDIT"
    Write-Host "  BONUS"
    Write-Host "  RECORDS"
    Write-Host "  OPTIONS"
    Write-Host ""
    Write-Host "This is intentionally a quick navigation patch, not final typography." -ForegroundColor Yellow
}
finally {
    Pop-Location
}

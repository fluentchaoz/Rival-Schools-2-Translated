param(
    [Parameter(Mandatory=$true)]
    [string]$RomFolder
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Run-Native([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail "$Command failed with exit code $LASTEXITCODE"
    }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder. Run the Phase 1 / Gate 1 scripts first."
}

$bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
if ($bins.Count -ne 1) {
    Fail "Expected exactly one .bin in $RomFolder; found $($bins.Count)."
}

$SourceBin = $bins[0].FullName
$hash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
if ($hash -ne $ExpectedBinHash) {
    Fail "This is not the exact BIN we audited."
}

Push-Location $Upstream
try {
    $ProbePath = Join-Path $Upstream "src/source_disc.rs"
    $ProbeMarker = "fn english_gate2_first_visible_text_build()"

    $sourceText = [System.IO.File]::ReadAllText($ProbePath)
    if (-not $sourceText.Contains($ProbeMarker)) {
        $Probe = @'

#[cfg(test)]
mod english_gate2_first_visible_text {
    use super::*;
    use std::io::{Read, Seek, SeekFrom};
    use std::path::Path;

    const MENU_PATH: &str = "DAT2/MENU.BIZ";
    const PANEL_INDEX: usize = 6;
    const DESCRIPTION_TIM_FIRST_OFFSET: usize = 0x4b800;
    const DESCRIPTION_TIM_STRIDE: usize = 0x2800;
    const DESCRIPTION_TIM_OFFSET: usize =
        DESCRIPTION_TIM_FIRST_OFFSET + PANEL_INDEX * DESCRIPTION_TIM_STRIDE;

    fn glyph(ch: char) -> [u8; 7] {
        match ch {
            'A' => [0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
            'E' => [0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
            'G' => [0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01110],
            'H' => [0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
            'I' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b11111],
            'L' => [0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111],
            'N' => [0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
            'O' => [0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
            'R' => [0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
            'S' => [0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110],
            'T' => [0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
            'Y' => [0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100],
            ' ' => [0,0,0,0,0,0,0],
            _ => panic!("unsupported Gate 2 test glyph: {ch}"),
        }
    }

    fn draw_centered(
        pixels: &mut [u8],
        width: usize,
        height: usize,
        text: &str,
        y: usize,
        scale: usize,
    ) {
        let chars = text.chars().collect::<Vec<_>>();
        let char_width = 5 * scale;
        let spacing = scale;
        let text_width = chars.len() * char_width
            + chars.len().saturating_sub(1) * spacing;
        assert!(text_width <= width);
        assert!(y + 7 * scale <= height);
        let start_x = (width - text_width) / 2;

        for (i, ch) in chars.into_iter().enumerate() {
            if ch == ' ' {
                continue;
            }
            let rows = glyph(ch);
            let base_x = start_x + i * (char_width + spacing);
            for (row, bits) in rows.into_iter().enumerate() {
                for col in 0..5 {
                    if bits & (1 << (4 - col)) == 0 {
                        continue;
                    }
                    for sy in 0..scale {
                        for sx in 0..scale {
                            let px = base_x + col * scale + sx;
                            let py = y + row * scale + sy;
                            pixels[py * width + px] = 1;
                        }
                    }
                }
            }
        }
    }

    #[test]
    fn english_gate2_first_visible_text_build() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let source = SupportedSourceDisc::open(
            &root.join("roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"),
        )
        .expect("adapted source profile must accept the audited BIN");

        let (_, menu_stored) = source.read_record(MENU_PATH).unwrap();
        let mut menu_decoded = crate::compression::decompress(&menu_stored, false).unwrap();

        // This is the description texture for MODE SELECT entry 0:
        // 熱血青春日記2.  The native build uses index 0 for clear and index 1
        // for description ink, so no external font or private asset is needed.
        let cell = crate::tim::Cell {
            x: 0,
            y: 0,
            width: 176,
            height: 112,
        };

        let original_region =
            crate::tim::read_indexed_cell_without_clut_in_prefix(
                &menu_decoded,
                DESCRIPTION_TIM_OFFSET,
                cell,
            )
            .unwrap();
        assert!(
            original_region.iter().any(|&p| p != 0),
            "source description unexpectedly contains no visible pixels"
        );

        let mut pixels = vec![0u8; cell.width * cell.height];

        // Intentionally obvious proof text, not final typography.
        draw_centered(&mut pixels, cell.width, cell.height, "HELLO", 7, 4);
        draw_centered(&mut pixels, cell.width, cell.height, "RYAN", 41, 4);
        draw_centered(&mut pixels, cell.width, cell.height, "ENGLISH TEST", 86, 2);

        crate::tim::write_indexed_cell_without_clut_in_prefix(
            &mut menu_decoded,
            DESCRIPTION_TIM_OFFSET,
            cell,
            &pixels,
        )
        .expect("Gate 2 description write must fit the native TIM");

        assert_eq!(
            crate::tim::read_indexed_cell_without_clut_in_prefix(
                &menu_decoded,
                DESCRIPTION_TIM_OFFSET,
                cell,
            )
            .unwrap(),
            pixels,
            "Gate 2 description pixels did not read back before compression"
        );

        let (encoded, _, _) =
            crate::menu_compression::compress_menu_with_source_limits(
                &menu_decoded,
                &menu_stored,
            )
            .expect("Gate 2 MENU.BIZ compression must succeed");

        assert!(
            encoded.len() <= menu_stored.len(),
            "Gate 2 MENU.BIZ grew beyond its fixed record"
        );
        assert_eq!(
            &encoded[..4],
            &menu_stored[..4],
            "Gate 2 MENU.BIZ changed its native catalog prefix"
        );

        let mut padded = encoded;
        padded.resize(menu_stored.len(), 0);
        assert_eq!(
            crate::compression::decompress(&padded, true).unwrap(),
            menu_decoded,
            "Gate 2 MENU.BIZ compression did not round-trip"
        );

        let work = root.join("work");
        std::fs::create_dir_all(&work).unwrap();
        let output = work.join("gate2-english-test.bin");
        if output.exists() {
            std::fs::remove_file(&output).unwrap();
        }

        let rebuilt = crate::disc::rebuild::copy_and_replace_record(
            source.image_path(),
            &output,
            MENU_PATH,
            &padded,
        )
        .expect("Gate 2 disc rebuild must succeed");

        assert!(
            !rebuilt.changed_lbas.is_empty(),
            "Gate 2 build unexpectedly changed no sectors"
        );
        assert!(
            rebuilt
                .changed_lbas
                .iter()
                .all(|lba| rebuilt.target_lbas.contains(lba)),
            "Gate 2 build changed a sector outside MENU.BIZ"
        );

        let (observed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(
                source.image_path(),
                &output,
            )
            .expect("Gate 2 whole-disc comparison must succeed");

        assert_eq!(
            observed_lbas, rebuilt.changed_lbas,
            "Gate 2 whole-disc diff disagrees with rebuild plan"
        );

        let (_, rebuilt_menu) =
            crate::disc::rebuild::read_record(&output, MENU_PATH).unwrap();
        let rebuilt_decoded =
            crate::compression::decompress(&rebuilt_menu, true).unwrap();

        assert_eq!(
            crate::tim::read_indexed_cell_without_clut_in_prefix(
                &rebuilt_decoded,
                DESCRIPTION_TIM_OFFSET,
                cell,
            )
            .unwrap(),
            pixels,
            "Gate 2 English pixels did not survive disc readback"
        );

        let mut file = std::fs::File::open(&output).unwrap();
        for &lba in &observed_lbas {
            let mut sector = [0u8; crate::disc::RAW_SECTOR_SIZE];
            file.seek(SeekFrom::Start(
                u64::from(lba) * crate::disc::RAW_SECTOR_SIZE as u64,
            ))
            .unwrap();
            file.read_exact(&mut sector).unwrap();
            assert!(
                crate::disc::mode2::verify(&sector),
                "Gate 2 rebuilt raw sector {lba} failed Mode-2 EDC/ECC verification"
            );
        }

        println!("GATE2_DESCRIPTION_TIM_OFFSET=0x{DESCRIPTION_TIM_OFFSET:x}");
        println!("GATE2_CHANGED_LBAS={:?}", observed_lbas);
        println!("GATE2_MENU_RECORD_EXTENT={:?}", rebuilt.target_lbas);
        println!("GATE2_OUTPUT_SHA256={output_sha256}");
    }
}
'@

        [System.IO.File]::AppendAllText(
            $ProbePath,
            $Probe,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    Write-Host "Justice Gakuen English Project - Gate 2 first visible English" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1/3] Building HELLO RYAN / ENGLISH TEST into the Seishun Nikki 2 description panel..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_gate2_first_visible_text::english_gate2_first_visible_text_build",
        "--", "--exact", "--nocapture"
    )

    $BuiltBin = Join-Path $Upstream "work/gate2-english-test.bin"
    if (-not (Test-Path $BuiltBin)) {
        Fail "Rust test passed but gate2-english-test.bin was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Hashing Gate 2 output..."
    $outHash = (Get-FileHash -Algorithm SHA256 $BuiltBin).Hash.ToLower()
    Write-Host "Gate 2 BIN SHA-256: $outHash"
    if ($outHash -eq $ExpectedBinHash) {
        Fail "Gate 2 output is unexpectedly identical to the source."
    }

    Write-Host ""
    Write-Host "[3/3] Writing matching CUE..."
    $BuiltCue = Join-Path $Upstream "work/gate2-english-test.cue"
    @'
FILE "gate2-english-test.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $BuiltCue

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "GATE 2 ENGLISH TEST BUILD PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "BIN: $BuiltBin"
    Write-Host "CUE: $BuiltCue"
    Write-Host ""
    Write-Host "Boot gate2-english-test.cue in DuckStation."
    Write-Host "At MODE SELECT, leave the first item selected."
    Write-Host "The yellow description box should say:"
    Write-Host "    HELLO"
    Write-Host "    RYAN"
    Write-Host "    ENGLISH TEST"
}
finally {
    Pop-Location
}

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

$InputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus.bin"
$ExpectedInputHash = "a8f2c7d4ebc025376a36ba84930dee75e6044632e04677ba1eff8cf6d70f0564"

if (-not (Test-Path $ProbePath)) {
    Fail "Missing upstream\src\source_disc.rs."
}
if (-not (Test-Path $InputBin)) {
    Fail "Missing the successful English Mode Select BIN."
}

$InputHash = (Get-FileHash -Algorithm SHA256 $InputBin).Hash.ToLower()
Write-Host ("Input BIN SHA-256: {0}" -f $InputHash)
if ($InputHash -ne $ExpectedInputHash) {
    Fail "Input BIN is not the exact successful English Mode Select build."
}

$Marker = "fn english_quick_school_life_title_menu_patch()"
$SourceText = [System.IO.File]::ReadAllText($ProbePath)

if (-not $SourceText.Contains($Marker)) {
$Rust = @'

#[cfg(test)]
mod english_quick_school_life_title_menu {
    use std::fs;
    use std::io::{Read, Seek, SeekFrom};
    use std::path::{Path, PathBuf};

    use anyhow::{Context, Result, ensure};
    use serde_json::json;

    use super::*;

    const SOURCE_HASH: &str =
        "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
    const INPUT_HASH: &str =
        "a8f2c7d4ebc025376a36ba84930dee75e6044632e04677ba1eff8cf6d70f0564";

    const OVERLAY_PATH: &str = "DAT1/MGTIT.BIZ";
    const RUNTIME_BASE: u32 = 0x800a_2000;
    const PLACEMENT_TABLE_OFFSET: usize = 0x02a0;
    const PLACEMENT_RECORD_SIZE: usize = 12;
    const PLACEMENT_RECORD_COUNT: usize = 18;

    #[derive(Clone, Debug)]
    struct Placement {
        index: usize,
        record_offset: usize,
        x: i16,
        y: i16,
        string_offset: usize,
        codes: Vec<u16>,
    }

    fn read_u16(data: &[u8], offset: usize) -> Result<u16> {
        let bytes = data
            .get(offset..offset + 2)
            .context("truncated u16")?;
        Ok(u16::from_le_bytes(bytes.try_into()?))
    }

    fn read_i16(data: &[u8], offset: usize) -> Result<i16> {
        Ok(read_u16(data, offset)? as i16)
    }

    fn read_u32(data: &[u8], offset: usize) -> Result<u32> {
        let bytes = data
            .get(offset..offset + 4)
            .context("truncated u32")?;
        Ok(u32::from_le_bytes(bytes.try_into()?))
    }

    fn placements(decoded: &[u8]) -> Result<Vec<Placement>> {
        let mut out = Vec::new();
        for index in 0..PLACEMENT_RECORD_COUNT {
            let record_offset =
                PLACEMENT_TABLE_OFFSET + index * PLACEMENT_RECORD_SIZE;
            let x = read_i16(decoded, record_offset)?;
            let y = read_i16(decoded, record_offset + 2)?;
            let pointer = read_u32(decoded, record_offset + 4)?;
            ensure!(
                read_u32(decoded, record_offset + 8)? == 0,
                "placement {index} reserved word changed"
            );
            let relative = pointer
                .checked_sub(RUNTIME_BASE)
                .context("placement pointer below MGTIT runtime base")?;
            let string_offset = usize::try_from(relative)?;
            let codes =
                crate::text::read_length_prefixed_codes(decoded, string_offset)?;
            out.push(Placement {
                index,
                record_offset,
                x,
                y,
                string_offset,
                codes,
            });
        }
        Ok(out)
    }

    fn safe_owned_size(
        decoded: &[u8],
        all_offsets: &[usize],
        p: &Placement,
        target: &str,
    ) -> Result<usize> {
        let source_size = 2 + p.codes.len() * 2;
        let target_size = 2 + target.chars().count() * 2;
        let owned = source_size.max(target_size);
        let end = p
            .string_offset
            .checked_add(owned)
            .context("owned title-menu range overflow")?;
        ensure!(end <= decoded.len(), "owned title-menu range is out of bounds");

        for other in all_offsets {
            if *other != p.string_offset
                && *other > p.string_offset
                && *other < end
            {
                anyhow::bail!(
                    "extending string at +0x{:04x} to {} bytes would overlap another placement at +0x{:04x}",
                    p.string_offset,
                    owned,
                    other
                );
            }
        }

        if owned > source_size {
            ensure!(
                decoded[p.string_offset + source_size..end]
                    .iter()
                    .all(|b| *b == 0),
                "NEW GAME needs {} bytes but the {} extra bytes after the source record are not zero",
                owned,
                owned - source_size
            );
        }
        Ok(owned)
    }

    fn find_pair(all: &[Placement]) -> Result<(Placement, Placement)> {
        println!("MGTIT placement table:");
        for p in all {
            println!(
                "  idx={:02} placement=+0x{:04x} x={:4} y={:4} string=+0x{:04x} glyphs={} codes={:?}",
                p.index,
                p.record_offset,
                p.x,
                p.y,
                p.string_offset,
                p.codes.len(),
                p.codes
            );
        }

        let mut pairs = Vec::new();
        for new_game in all.iter().filter(|p| {
            p.codes.len() == 4
                && (10..=100).contains(&p.x)
                && (0..=50).contains(&p.y)
        }) {
            for cont in all.iter().filter(|p| {
                p.codes.len() == 9
                    && (10..=100).contains(&p.x)
                    && (15..=85).contains(&p.y)
            }) {
                let x_delta = (i32::from(new_game.x) - i32::from(cont.x)).abs();
                let y_delta = i32::from(cont.y) - i32::from(new_game.y);
                if cont.index == new_game.index + 1
                    && x_delta <= 12
                    && (8..=40).contains(&y_delta)
                {
                    pairs.push((new_game.clone(), cont.clone()));
                }
            }
        }

        ensure!(
            pairs.len() == 1,
            "expected exactly one upper-left adjacent 4-glyph/9-glyph title-menu pair, found {}",
            pairs.len()
        );
        Ok(pairs.remove(0))
    }

    fn write_json(path: &Path, value: &serde_json::Value) -> Result<()> {
        fs::write(path, serde_json::to_vec_pretty(value)?)?;
        Ok(())
    }

    #[test]
    fn english_quick_school_life_title_menu_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));

        let source_cue = root.join(
            "roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue",
        );
        ensure!(source_cue.is_file(), "original source CUE is missing");

        let input = root.join(
            "work/english-batsu-playable-scene1/build/justice-gakuen2-batsu-english-scene1-menus.bin",
        );
        ensure!(input.is_file(), "English Mode Select BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(&input)? == INPUT_HASH,
            "English Mode Select BIN hash changed"
        );

        let source = SupportedSourceDisc::open(&source_cue)?;
        ensure!(
            source.source_bin_sha256() == SOURCE_HASH,
            "original source disc hash changed"
        );

        let (_, source_menu_stored) = source.read_record("DAT2/MENU.BIZ")?;
        let source_menu_decoded =
            crate::compression::decompress(&source_menu_stored, false)?;
        let (_, source_overlay_stored) = source.read_record(OVERLAY_PATH)?;
        let source_overlay_decoded =
            crate::compression::decompress(&source_overlay_stored, false)?;

        // The combined input must still contain the exact original MGTIT before
        // this stage so we know we are composing independent patches.
        let (_, input_overlay) =
            crate::disc::rebuild::read_record(&input, OVERLAY_PATH)?;
        ensure!(
            input_overlay == source_overlay_stored,
            "combined menu build already changed MGTIT.BIZ"
        );

        let table = placements(&source_overlay_decoded)?;
        let (new_game, cont) = find_pair(&table)?;

        println!(
            "Matched NEW GAME source: idx={} x={} y={} string=+0x{:04x} glyphs={}",
            new_game.index,
            new_game.x,
            new_game.y,
            new_game.string_offset,
            new_game.codes.len()
        );
        println!(
            "Matched CONTINUE source: idx={} x={} y={} string=+0x{:04x} glyphs={}",
            cont.index,
            cont.x,
            cont.y,
            cont.string_offset,
            cont.codes.len()
        );

        let all_offsets =
            table.iter().map(|p| p.string_offset).collect::<Vec<_>>();

        let mut first_target = "NEW GAME".to_string();
        let first_size = match safe_owned_size(
            &source_overlay_decoded,
            &all_offsets,
            &new_game,
            &first_target,
        ) {
            Ok(size) => size,
            Err(error) => {
                println!(
                    "NEW GAME does not safely fit ({error}); falling back to NEW"
                );
                first_target = "NEW".to_string();
                safe_owned_size(
                    &source_overlay_decoded,
                    &all_offsets,
                    &new_game,
                    &first_target,
                )?
            }
        };
        let continue_target = "CONTINUE".to_string();
        let continue_size = safe_owned_size(
            &source_overlay_decoded,
            &all_offsets,
            &cont,
            &continue_target,
        )?;

        println!("First label target: {first_target}");
        println!("Second label target: {continue_target}");

        let assets = root.join(
            "work/english-batsu-playable-scene1/quick-title-menu-assets",
        );
        if assets.exists() {
            fs::remove_dir_all(&assets)?;
        }
        fs::create_dir_all(&assets)?;

        let build_dir = root.join(
            "work/english-batsu-playable-scene1/quick-title-menu-build",
        );
        if build_dir.exists() {
            fs::remove_dir_all(&build_dir)?;
        }

        let menu_stored_sha = crate::pipeline::sha256_bytes(&source_menu_stored);
        let menu_decoded_sha = crate::pipeline::sha256_bytes(&source_menu_decoded);
        let overlay_stored_sha =
            crate::pipeline::sha256_bytes(&source_overlay_stored);
        let overlay_decoded_sha =
            crate::pipeline::sha256_bytes(&source_overlay_decoded);

        let entry_json = |id: &str,
                          p: &Placement,
                          owned_size: usize,
                          source_label: &str,
                          target: &str|
         -> serde_json::Value {
            let source_end = p.string_offset + owned_size;
            let placement =
                &source_overlay_decoded[p.record_offset..p.record_offset + 12];
            json!({
                "kind": "Justice Gakuen 2 title-adjacent menu translation unit",
                "id": id,
                "source_offset": format!("0x{:x}", p.string_offset),
                "source_record_size": owned_size,
                "source_record_sha256": crate::pipeline::sha256_bytes(
                    &source_overlay_decoded[p.string_offset..source_end]
                ),
                "source_codes": p.codes.iter()
                    .map(|code| format!("0x{code:04x}"))
                    .collect::<Vec<_>>(),
                "source_text": source_label,
                "korean_text": target,
                "placement_record_offset": format!("0x{:x}", p.record_offset),
                "source_x": p.x,
                "source_y": p.y,
                "source_placement_sha256": crate::pipeline::sha256_bytes(placement),
                "development_status": "authored",
                "release_status": "needs_human_review"
            })
        };

        write_json(
            &assets.join("new_enrollment.json"),
            &entry_json(
                "new_enrollment",
                &new_game,
                first_size,
                "source_new_enrollment",
                &first_target,
            ),
        )?;
        write_json(
            &assets.join("continue_session.json"),
            &entry_json(
                "continue_session",
                &cont,
                continue_size,
                "source_continue_session",
                &continue_target,
            ),
        )?;

        write_json(
            &assets.join("manifest.json"),
            &json!({
                "kind": "Justice Gakuen 2 title-adjacent menu translation manifest",
                "source_bin_sha256": SOURCE_HASH,
                "menu_path": "DAT2/MENU.BIZ",
                "menu_stored_sha256": menu_stored_sha,
                "menu_decoded_sha256": menu_decoded_sha,
                "overlay_path": OVERLAY_PATH,
                "overlay_stored_sha256": overlay_stored_sha,
                "overlay_decoded_sha256": overlay_decoded_sha,
                "entries": [
                    {"id": "new_enrollment", "file": "new_enrollment.json"},
                    {"id": "continue_session", "file": "continue_session.json"}
                ]
            }),
        )?;

        let font = PathBuf::from(r"C:\Windows\Fonts\arial.ttf");
        ensure!(font.is_file(), "Arial font is missing");

        let built = crate::title_menu::build_title_menu_assets(
            &crate::title_menu::TitleMenuBuildConfig {
                cue: source_cue,
                assets,
                font: crate::title_menu::TitleMenuFontStyle {
                    font,
                    font_px: 13.0,
                },
                build_spec_sha256:
                    "english-quick-school-life-title-menu-v1".to_string(),
                output_dir: build_dir,
                force: true,
            },
        )?;

        ensure!(
            built.report.entry_count == 2,
            "title-menu build did not produce exactly two entries"
        );
        ensure!(
            built.menu_stored == source_menu_stored,
            "title-menu helper unexpectedly changed global MENU.BIZ"
        );

        let output = root.join(
            "work/english-batsu-playable-scene1/build/justice-gakuen2-batsu-english-scene1-menus-title.bin",
        );
        if output.exists() {
            fs::remove_file(&output)?;
        }

        let rebuilt = crate::disc::rebuild::copy_and_replace_record(
            &input,
            &output,
            OVERLAY_PATH,
            &built.overlay_stored,
        )?;

        ensure!(
            rebuilt
                .changed_lbas
                .iter()
                .all(|lba| rebuilt.target_lbas.contains(lba)),
            "MGTIT patch changed sectors outside the target record"
        );

        let (_, readback) =
            crate::disc::rebuild::read_record(&output, OVERLAY_PATH)?;
        ensure!(
            readback == built.overlay_stored,
            "MGTIT readback differs from rebuilt overlay"
        );

        let (changed, output_sha) =
            crate::disc::rebuild::compare_and_hash_images(&input, &output)?;
        ensure!(
            changed == rebuilt.changed_lbas,
            "disc comparison changed-LBA set differs from record replacement"
        );

        let mut file = fs::File::open(&output)?;
        for &lba in &changed {
            let mut sector = [0u8; crate::disc::RAW_SECTOR_SIZE];
            file.seek(SeekFrom::Start(
                u64::from(lba) * crate::disc::RAW_SECTOR_SIZE as u64,
            ))?;
            file.read_exact(&mut sector)?;
            ensure!(
                crate::disc::mode2::verify(&sector),
                "rebuilt MGTIT raw sector {lba} failed Mode-2 verification"
            );
        }

        println!("TITLE_MENU_CHANGED_LBAS={changed:?}");
        println!("TITLE_MENU_OUTPUT_SHA256={output_sha}");
        println!("TITLE_MENU_FIRST_LABEL={first_target}");
        println!("TITLE_MENU_SECOND_LABEL={continue_target}");
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
Write-Host "Justice Gakuen English Project - School Life Start Menu" -ForegroundColor Cyan
Write-Host ""
Write-Host "[1/3] Discovering and translating NEW GAME / CONTINUE..."

Push-Location $Upstream
try {
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_quick_school_life_title_menu::english_quick_school_life_title_menu_patch",
        "--", "--exact", "--nocapture"
    )

    $OutputBin = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus-title.bin"
    if (-not (Test-Path $OutputBin)) {
        Fail "School Life title-menu test passed but no output BIN was produced."
    }

    Write-Host ""
    Write-Host "[2/3] Writing matching CUE..."
    $OutputCue = Join-Path $Upstream "work\english-batsu-playable-scene1\build\justice-gakuen2-batsu-english-scene1-menus-title.cue"
    @'
FILE "justice-gakuen2-batsu-english-scene1-menus-title.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $OutputCue

    Write-Host ""
    Write-Host "[3/3] Hashing final build..."
    $OutputHash = (Get-FileHash -Algorithm SHA256 $OutputBin).Hash.ToLower()
    Write-Host ("Output SHA-256: {0}" -f $OutputHash)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "SCHOOL LIFE START MENU ENGLISH BUILD COMPLETE" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Open THIS CUE in DuckStation:" -ForegroundColor Yellow
    Write-Host $OutputCue -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Expected screen:" -ForegroundColor Cyan
    Write-Host "  NEW GAME"
    Write-Host "  CONTINUE"
}
finally {
    Pop-Location
}

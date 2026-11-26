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
        Fail ("{0} {1} failed with exit code {2}" -f $Command, ($Arguments -join " "), $LASTEXITCODE)
    }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$RustPath = Join-Path $Upstream "src\dialogue_audit\name_entry_input_tests.rs"

$MasterBin = Join-Path $Upstream "work\english-mgk10-quiz-v15b\build\justice-gakuen2-mgk10-quiz-v15b.bin"
$ExpectedMasterHash = "4c43c6a02e15bd5d470a649ab17b9ff4905c0c8b63ad77e91ea57afcb38e42c5"

$SourceBin = "C:\Users\Fluent\Downloads\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan)\Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

$TranslationJson = Join-Path $Here "mgk04-selector6-english-v1.json"
$ExpectedTranslationHash = "aeae238d3b6c7a768950c922ee964db70468ac11f5c00475f3f4d857dca046d0"

$WorkRoot = Join-Path $Upstream "work\english-live-mgk04-quiz-v16"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-live-mgk04-quiz-v16.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-live-mgk04-quiz-v16.cue"
$ReportJson = Join-Path $BuildDir "mgk04-live-quiz-v16-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - LIVE MGK04 QUIZ ENGLISH v16" -ForegroundColor Cyan
Write-Host ""

foreach ($p in @($Upstream, $RustPath, $MasterBin, $SourceBin, $TranslationJson)) {
    if (-not (Test-Path $p)) {
        Fail ("Missing required path: {0}" -f $p)
    }
}

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v15b master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v15b master hash mismatch. Nothing was changed."
}

$SourceHash = (Get-FileHash $SourceBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Original source BIN SHA-256: {0}" -f $SourceHash)
if ($SourceHash -ne $ExpectedSourceHash) {
    Fail "Original source hash mismatch. Nothing was changed."
}

$TranslationHash = (Get-FileHash $TranslationJson -Algorithm SHA256).Hash.ToLower()
Write-Host ("Translation JSON SHA-256: {0}" -f $TranslationHash)
if ($TranslationHash -ne $ExpectedTranslationHash) {
    Fail "Translation JSON hash mismatch. Use the exact mgk04-selector6-english-v1.json supplied in chat."
}

# Fast PowerShell-side shape audit before touching Rust.
$Translation = Get-Content $TranslationJson -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$Translation.source_entry_count -ne 100) { Fail "Translation JSON does not contain 100 entries." }
if ([int]$Translation.question_count -ne 20) { Fail "Translation JSON does not contain 20 questions." }
if ([int]$Translation.answer_count -ne 80) { Fail "Translation JSON does not contain 80 answers." }
if ($Translation.entries.Count -ne 100) { Fail "Translation JSON entries array is not length 100." }

for ($i = 0; $i -lt 100; $i++) {
    $e = $Translation.entries[$i]
    if ([int]$e.entry_index -ne $i) {
        Fail ("Translation JSON entry ordering changed at {0}." -f $i)
    }
    if (-not [bool]$e.layout_ok) {
        Fail ("Translation JSON reports layout failure at entry {0}." -f $i)
    }
}

Write-Host "v15b, source ROM, and 100-entry translation packet verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_LIVE_MGK04_QUIZ_V16"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v16 injection already exists in name_entry_input_tests.rs."
}

function RustLiteral([string]$Value) {
    return $Value.Replace("\", "\\").Replace('"', '\"')
}

$MasterLiteral = RustLiteral $MasterBin
$SourceLiteral = RustLiteral $SourceBin
$TranslationLiteral = RustLiteral $TranslationJson
$OutputBinLiteral = RustLiteral $OutputBin
$OutputCueLiteral = RustLiteral $OutputCue
$ReportLiteral = RustLiteral $ReportJson

$Rust = @"

// ENGLISH_PROJECT_LIVE_MGK04_QUIZ_V16
#[test]
fn english_project_live_mgk04_quiz_v16() -> anyhow::Result<()> {
    use anyhow::{Context, Result, ensure};
    use serde_json::{Value, json};
    use std::collections::{BTreeMap, BTreeSet};
    use std::fs;
    use std::path::Path;

    use crate::font::{HorizontalTextAlignment, IndexedTextRasterizer};

    const MASTER: &str = "$MasterLiteral";
    const SOURCE: &str = "$SourceLiteral";
    const TRANSLATION_JSON: &str = "$TranslationLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";

    const MASTER_SHA256: &str =
        "4c43c6a02e15bd5d470a649ab17b9ff4905c0c8b63ad77e91ea57afcb38e42c5";
    const SOURCE_SHA256: &str =
        "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
    const TRANSLATION_SHA256: &str =
        "aeae238d3b6c7a768950c922ee964db70468ac11f5c00475f3f4d857dca046d0";

    const RECORD_PATH: &str = "DAT2/MGK04.BIZ";
    const TARGET_SELECTOR: usize = 6;
    const TARGET_ENTRY_COUNT: usize = 100;
    const RUNTIME_BASE: u32 = 0x800d_0000;
    const FONT: &str = "C:\\Windows\\Fonts\\arial.ttf";

    fn parse_target_markup(markup: &str) -> Result<(Vec<String>, Vec<u16>)> {
        ensure!(
            markup.ends_with("{#message_end}"),
            "target markup lacks final message_end"
        );

        let mut segments = Vec::<String>::new();
        let mut controls = Vec::<u16>::new();
        let mut cursor = 0usize;

        while cursor < markup.len() {
            let rest = &markup[cursor..];
            let Some(open_rel) = rest.find("{#") else {
                anyhow::bail!("target markup has trailing text without message_end");
            };
            let open = cursor + open_rel;
            segments.push(markup[cursor..open].to_string());

            let control_rest = &markup[open..];
            if control_rest.starts_with("{#line_break}") {
                controls.push(0x3000);
                cursor = open + "{#line_break}".len();
            } else if control_rest.starts_with("{#message_end}") {
                controls.push(0x3001);
                cursor = open + "{#message_end}".len();
                ensure!(cursor == markup.len(), "text follows message_end");
            } else {
                anyhow::bail!("unsupported target control near {:?}", control_rest);
            }
        }

        ensure!(
            segments.len() == controls.len(),
            "target segment/control shape is unexpected"
        );
        ensure!(
            controls.last() == Some(&0x3001),
            "target does not end in message_end"
        );
        ensure!(
            controls.iter().filter(|&&code| code == 0x3001).count() == 1,
            "target contains multiple message_end controls"
        );

        Ok((segments, controls))
    }

    fn encode_target(
        markup: &str,
        character_codes: &BTreeMap<char, u16>,
    ) -> Result<Vec<u8>> {
        let (segments, controls) = parse_target_markup(markup)?;
        let mut words = Vec::<u16>::new();

        for (segment, control) in segments.iter().zip(controls.iter()) {
            for ch in segment.chars() {
                let code = character_codes
                    .get(&ch)
                    .with_context(|| format!("target character {:?} lacks installed code", ch))?;
                words.push(*code);
            }
            words.push(*control);
        }

        if !words.len().is_multiple_of(2) {
            words.push(0);
        }

        Ok(words
            .into_iter()
            .flat_map(u16::to_le_bytes)
            .collect::<Vec<_>>())
    }

    fn source_palette_indices(decoded: &[u8]) -> Result<(u8, Option<u8>, u8)> {
        let atlas = super::atlas::parse_dialogue_atlas(decoded)?;
        let start = atlas.pixel_data_offset;
        let end = start + atlas.fixed_cell_count * super::atlas::GLYPH_CELL_BYTE_COUNT;
        ensure!(end <= decoded.len(), "dialogue fixed atlas is truncated");

        let mut counts = [0usize; 16];
        for &byte in &decoded[start..end] {
            counts[usize::from(byte & 0x0f)] += 1;
            counts[usize::from(byte >> 4)] += 1;
        }

        let clear = (0u8..16)
            .max_by_key(|i| counts[usize::from(*i)])
            .context("dialogue atlas has no pixels")?;

        let mut inks = (0u8..16)
            .filter(|i| *i != clear && counts[usize::from(*i)] > 0)
            .collect::<Vec<_>>();
        inks.sort_by_key(|i| std::cmp::Reverse(counts[usize::from(*i)]));
        ensure!(!inks.is_empty(), "dialogue atlas has no visible ink index");

        if inks.len() == 1 {
            Ok((clear, None, inks[0]))
        } else {
            // Most-used non-background index is treated as fill;
            // second-most-used as outline.
            Ok((clear, Some(inks[1]), inks[0]))
        }
    }

    fn rasterize_char(
        rasterizer: &IndexedTextRasterizer,
        ch: char,
        clear: u8,
        outline: Option<u8>,
        fill: u8,
    ) -> Result<crate::font::RasterizedIndexedText> {
        let text = ch.to_string();
        let mut font_px = 14.0f32;
        loop {
            match rasterizer.rasterize(
                &text,
                20,
                20,
                font_px,
                0.0,
                clear,
                outline,
                fill,
                HorizontalTextAlignment::Center,
            ) {
                Ok(rendered) => return Ok(rendered),
                Err(error) => {
                    let message = error.to_string();
                    if message.contains(" needs ")
                        && message.contains(" owns ")
                        && font_px > 8.0
                    {
                        font_px -= 0.5;
                        continue;
                    }
                    return Err(error);
                }
            }
        }
    }

    let master = Path::new(MASTER);
    let source = Path::new(SOURCE);
    let translation_path = Path::new(TRANSLATION_JSON);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let report_path = Path::new(REPORT);

    ensure!(master.is_file(), "v15b master BIN missing");
    ensure!(source.is_file(), "original source BIN missing");
    ensure!(translation_path.is_file(), "translation JSON missing");

    ensure!(
        crate::pipeline::sha256_file(master)? == MASTER_SHA256,
        "v15b master SHA changed"
    );
    ensure!(
        crate::pipeline::sha256_file(source)? == SOURCE_SHA256,
        "source BIN SHA changed"
    );
    ensure!(
        crate::pipeline::sha256_file(translation_path)? == TRANSLATION_SHA256,
        "translation JSON SHA changed"
    );

    let (_, master_stored) = crate::disc::rebuild::read_record(master, RECORD_PATH)?;
    let (_, source_stored) = crate::disc::rebuild::read_record(source, RECORD_PATH)?;

    let master_stored_sha256 = crate::pipeline::sha256_bytes(&master_stored);
    let source_stored_sha256 = crate::pipeline::sha256_bytes(&source_stored);
    let master_decoded = crate::compression::decompress(&master_stored, true)?;
    let source_decoded = crate::compression::decompress(&source_stored, true)?;
    let mut patched_decoded = master_decoded.clone();

    let translation_bytes = fs::read(translation_path)?;
    let translation: Value = serde_json::from_slice(&translation_bytes)?;

    ensure!(
        translation["source_path"].as_str() == Some(RECORD_PATH),
        "translation JSON source_path changed"
    );
    ensure!(
        translation["selector_index"].as_u64() == Some(TARGET_SELECTOR as u64),
        "translation JSON selector changed"
    );

    let entries = translation["entries"]
        .as_array()
        .context("translation JSON entries is not an array")?;
    ensure!(
        entries.len() == TARGET_ENTRY_COUNT,
        "translation JSON does not contain 100 entries"
    );

    let parsed_banks = super::parser::parse_dialogue_banks(&master_decoded)?;
    let source_banks = super::parser::parse_dialogue_banks(&source_decoded)?;

    let bank = parsed_banks
        .iter()
        .find(|bank| bank.selector_index == TARGET_SELECTOR)
        .context("current MGK04 selector 6 is absent")?;
    let source_bank = source_banks
        .iter()
        .find(|bank| bank.selector_index == TARGET_SELECTOR)
        .context("source MGK04 selector 6 is absent")?;

    ensure!(
        bank.messages.len() >= TARGET_ENTRY_COUNT
            && source_bank.messages.len() >= TARGET_ENTRY_COUNT,
        "MGK04 selector 6 has fewer than 100 messages"
    );

    // Earlier MGK04 work intentionally changed other selectors. Prove that the
    // live quiz itself is still byte-identical to the verified Japanese source.
    for index in 0..TARGET_ENTRY_COUNT {
        ensure!(
            bank.messages[index].data == source_bank.messages[index].data,
            "current MGK04 selector 6 entry {index} no longer matches source"
        );
    }

    // Validate every translation entry and collect every ASCII character.
    let mut used_characters = BTreeSet::<char>::new();
    let mut targets = Vec::<String>::with_capacity(TARGET_ENTRY_COUNT);

    for (index, entry) in entries.iter().enumerate() {
        ensure!(
            entry["entry_index"].as_u64() == Some(index as u64),
            "translation entry index changed at {index}"
        );

        ensure!(
            entry["source_markup"].as_str().is_some(),
            "translation source markup missing at entry {index}"
        );
        ensure!(
            entry["layout_ok"].as_bool() == Some(true),
            "translation layout is not approved at entry {index}"
        );

        let target = entry["target_markup"]
            .as_str()
            .with_context(|| format!("entry {index} lacks target_markup"))?
            .to_string();

        let (segments, controls) = parse_target_markup(&target)?;
        let is_question = index % 5 == 0;

        if is_question {
            ensure!(
                controls.iter().filter(|&&code| code == 0x3000).count() <= 2,
                "question entry {index} exceeds 3 visible rows"
            );
            for segment in &segments {
                ensure!(
                    segment.chars().count() <= 16,
                    "question entry {index} exceeds 16 cells on one row"
                );
            }
        } else {
            ensure!(
                controls.iter().all(|&code| code != 0x3000),
                "answer entry {index} unexpectedly contains a line break"
            );
            let glyph_count = segments.iter().map(|s| s.chars().count()).sum::<usize>();
            ensure!(
                glyph_count <= 19,
                "answer entry {index} exceeds 19 glyph slots"
            );
        }

        for segment in segments {
            for ch in segment.chars() {
                ensure!(
                    ch.is_ascii(),
                    "entry {index} contains non-ASCII target character {:?}",
                    ch
                );
                used_characters.insert(ch);
            }
        }
        targets.push(target);
    }

    let atlas = super::atlas::parse_dialogue_atlas(&patched_decoded)?;
    let slot_size = super::atlas::GLYPH_CELL_BYTE_COUNT;

    // Discover genuinely empty renderer-addressable slots.
    let mut empty_slots = Vec::<u16>::new();
    for code in atlas.fixed_cell_count..atlas.addressable_slot_count {
        let start = atlas.pixel_data_offset + code * slot_size;
        let end = start + slot_size;
        ensure!(end <= patched_decoded.len(), "extension glyph slot is truncated");
        if patched_decoded[start..end].iter().all(|byte| *byte == 0) {
            empty_slots.push(u16::try_from(code)?);
        }
    }

    // Space needs a genuinely blank slot, but does not need rasterization.
    let needs_space = used_characters.remove(&' ');
    let required_visible = used_characters.len();
    let required_total = required_visible + usize::from(needs_space);

    ensure!(
        empty_slots.len() >= required_total,
        "MGK04 has only {} empty extension glyph slots; {} are required",
        empty_slots.len(),
        required_total
    );

    let (clear, outline, fill) = source_palette_indices(&master_decoded)?;
    let rasterizer = IndexedTextRasterizer::load(Path::new(FONT))?;
    let mut character_codes = BTreeMap::<char, u16>::new();
    let mut slot_cursor = 0usize;

    if needs_space {
        character_codes.insert(' ', empty_slots[slot_cursor]);
        slot_cursor += 1;
    }

    let mut glyph_report = Vec::new();
    for ch in used_characters {
        let code = empty_slots[slot_cursor];
        slot_cursor += 1;

        let rendered = rasterize_char(&rasterizer, ch, clear, outline, fill)?;
        let install = super::install_dialogue_extension_glyph(
            &mut patched_decoded,
            code,
            &rendered.pixels,
        )?;

        character_codes.insert(ch, code);
        glyph_report.push(json!({
            "character": ch.to_string(),
            "code": format!("0x{code:04x}"),
            "changed_decoded_byte_count": install.changed_decoded_byte_count,
            "cell_sha256": install.cell_sha256,
        }));
    }

    // Rebuild the entire shared dialogue message arena, matching the upstream
    // project's own dialogue_message_rebuild strategy. Selector 6 may grow;
    // later banks simply move forward and all selector/message pointers are
    // rewritten. The primary script at 0x4a000 and everything after it remain
    // byte-identical.
    const SELECTOR_TABLE_OFFSET: usize = 0x31_000;
    const SELECTOR_SLOT_COUNT: usize = 8;
    const PRIMARY_SCRIPT_OFFSET: usize = 0x4a000;
    const POINTER_TABLE_TERMINATOR: u32 = u32::MAX;

    let message_arena_start = SELECTOR_TABLE_OFFSET + SELECTOR_SLOT_COUNT * 4;
    ensure!(
        parsed_banks
            .first()
            .is_some_and(|bank| bank.message_data_start == message_arena_start),
        "MGK04 message arena start changed"
    );

    let original_script_and_later = master_decoded[PRIMARY_SCRIPT_OFFSET..].to_vec();

    // Prepare the English selector-6 message set. Any selector-6 messages after
    // the quiz's first 100 entries remain byte-identical.
    let mut translated_selector6_messages =
        Vec::<Vec<u8>>::with_capacity(bank.messages.len());
    for (index, message) in bank.messages.iter().enumerate() {
        let bytes = if index < TARGET_ENTRY_COUNT {
            encode_target(&targets[index], &character_codes)?
        } else {
            message.data.clone()
        };
        ensure!(
            bytes.len().is_multiple_of(4),
            "selector 6 entry {index} lost 4-byte alignment"
        );
        translated_selector6_messages.push(bytes);
    }
    let translated_selector6_message_bytes =
        translated_selector6_messages.iter().map(Vec::len).sum::<usize>();
    let current_selector6_message_bytes =
        bank.messages.iter().map(|message| message.data.len()).sum::<usize>();

    // Wipe only the selector table + shared message arena. Glyph extension data
    // lives before 0x31000 and was installed above, so it is preserved.
    patched_decoded[SELECTOR_TABLE_OFFSET..PRIMARY_SCRIPT_OFFSET].fill(0);

    let mut cursor = message_arena_start;
    let mut expected_messages = Vec::<Vec<Vec<u8>>>::with_capacity(parsed_banks.len());

    for original_bank in &parsed_banks {
        let mut offsets = Vec::<usize>::with_capacity(original_bank.messages.len());
        let mut expected_bank = Vec::<Vec<u8>>::with_capacity(original_bank.messages.len());

        for (message_index, original_message) in original_bank.messages.iter().enumerate() {
            let bytes = if original_bank.selector_index == TARGET_SELECTOR {
                translated_selector6_messages[message_index].clone()
            } else {
                original_message.data.clone()
            };

            ensure!(
                cursor.is_multiple_of(4) && bytes.len().is_multiple_of(4),
                "rebuilt dialogue message lost 4-byte alignment"
            );

            let start = cursor;
            let end = start
                .checked_add(bytes.len())
                .context("rebuilt dialogue message offset overflow")?;
            ensure!(
                end <= PRIMARY_SCRIPT_OFFSET,
                "rebuilt dialogue messages overlap primary script: need 0x{end:x}, limit 0x{PRIMARY_SCRIPT_OFFSET:x}"
            );

            patched_decoded[start..end].copy_from_slice(&bytes);
            offsets.push(start);
            expected_bank.push(bytes);
            cursor = end;
        }

        let pointer_table_offset = cursor;
        for message_offset in offsets {
            ensure!(
                cursor + 4 <= PRIMARY_SCRIPT_OFFSET,
                "rebuilt pointer table overlaps primary script"
            );
            let runtime_pointer = RUNTIME_BASE
                .checked_add(u32::try_from(message_offset)?)
                .context("rebuilt dialogue runtime pointer overflow")?;
            patched_decoded[cursor..cursor + 4]
                .copy_from_slice(&runtime_pointer.to_le_bytes());
            cursor += 4;
        }

        ensure!(
            cursor + 4 <= PRIMARY_SCRIPT_OFFSET,
            "rebuilt pointer-table terminator overlaps primary script"
        );
        patched_decoded[cursor..cursor + 4]
            .copy_from_slice(&POINTER_TABLE_TERMINATOR.to_le_bytes());
        cursor += 4;

        let selector_pointer = RUNTIME_BASE
            .checked_add(u32::try_from(pointer_table_offset)?)
            .context("selector pointer overflow")?;
        let selector_at = SELECTOR_TABLE_OFFSET + original_bank.selector_index * 4;
        patched_decoded[selector_at..selector_at + 4]
            .copy_from_slice(&selector_pointer.to_le_bytes());

        expected_messages.push(expected_bank);
    }

    let arena_used_bytes = cursor - message_arena_start;
    let arena_capacity_bytes = PRIMARY_SCRIPT_OFFSET - message_arena_start;
    let arena_spare_bytes = PRIMARY_SCRIPT_OFFSET - cursor;

    ensure!(
        cursor <= PRIMARY_SCRIPT_OFFSET,
        "rebuilt MGK04 dialogue arena exceeds primary-script boundary"
    );
    ensure!(
        patched_decoded[cursor..PRIMARY_SCRIPT_OFFSET]
            .iter()
            .all(|byte| *byte == 0),
        "unused message-arena suffix is not zero"
    );
    ensure!(
        patched_decoded[PRIMARY_SCRIPT_OFFSET..] == original_script_and_later,
        "message repack changed primary script or later data"
    );

    // Parse-back verification for every bank, not only selector 6.
    let rebuilt_banks = super::parser::parse_dialogue_banks(&patched_decoded)?;
    ensure!(
        rebuilt_banks.len() == parsed_banks.len(),
        "dialogue bank count changed after arena repack"
    );

    for ((rebuilt_bank, original_bank), expected_bank) in rebuilt_banks
        .iter()
        .zip(parsed_banks.iter())
        .zip(expected_messages.iter())
    {
        ensure!(
            rebuilt_bank.selector_index == original_bank.selector_index,
            "dialogue selector order changed"
        );
        ensure!(
            rebuilt_bank.messages.len() == original_bank.messages.len(),
            "dialogue message count changed in selector {}",
            original_bank.selector_index
        );
        for (message_index, (rebuilt_message, expected)) in rebuilt_bank
            .messages
            .iter()
            .zip(expected_bank.iter())
            .enumerate()
        {
            ensure!(
                rebuilt_message.data == *expected,
                "selector {} entry {} changed during parse-back",
                original_bank.selector_index,
                message_index
            );
        }
    }

    // Explicitly prove all non-target banks retained their exact message bytes.
    for (rebuilt_bank, original_bank) in rebuilt_banks.iter().zip(parsed_banks.iter()) {
        if original_bank.selector_index == TARGET_SELECTOR {
            continue;
        }
        ensure!(
            rebuilt_bank
                .messages
                .iter()
                .zip(original_bank.messages.iter())
                .all(|(rebuilt, original)| rebuilt.data == original.data),
            "non-target selector {} message payload changed",
            original_bank.selector_index
        );
    }

    let rebuilt_bank = rebuilt_banks
        .iter()
        .find(|bank| bank.selector_index == TARGET_SELECTOR)
        .context("rebuilt selector 6 is absent")?;

    for index in 0..TARGET_ENTRY_COUNT {
        let expected = encode_target(&targets[index], &character_codes)?;
        ensure!(
            rebuilt_bank.messages[index].data == expected,
            "selector 6 entry {index} readback differs before compression"
        );
    }

    let source_profile =
        crate::paged_compression::source_paged_compression_profile(&master_stored)?;
    let reencoded =
        crate::paged_compression::compress_page_safe_image(&patched_decoded, source_profile)?;

    ensure!(
        crate::compression::decompress(&reencoded, false)? == patched_decoded,
        "MGK04 compression roundtrip changed decoded data"
    );
    ensure!(
        reencoded.len() <= master_stored.len(),
        "English MGK04 exceeds current fixed record: compressed {} > source {}",
        reencoded.len(),
        master_stored.len()
    );

    let unpadded_compressed_size = reencoded.len();
    let mut patched_stored = reencoded;
    patched_stored.resize(master_stored.len(), 0);

    ensure!(
        crate::compression::decompress(&patched_stored, true)? == patched_decoded,
        "padded MGK04 record changed decoded data"
    );

    fs::create_dir_all(output_bin.parent().context("output BIN has no parent")?)?;

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: RECORD_PATH,
        data: &patched_stored,
    }];

    let rebuilt_records =
        crate::disc::rebuild::copy_and_replace_records(master, output_bin, &replacements)?;
    ensure!(
        rebuilt_records.len() == 1,
        "v16 replaced more than MGK04.BIZ"
    );

    let (_, record_readback) =
        crate::disc::rebuild::read_record(output_bin, RECORD_PATH)?;
    ensure!(
        record_readback == patched_stored,
        "MGK04 stored readback differs"
    );
    ensure!(
        crate::compression::decompress(&record_readback, true)? == patched_decoded,
        "MGK04 decoded readback differs"
    );
    ensure!(
        fs::metadata(master)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(master, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v16 changed no sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt_records.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v16 changed sectors outside MGK04.BIZ"
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
        "kind": "Justice Gakuen 2 live MGK04 quiz English v16",
        "input_master_sha256": MASTER_SHA256,
        "source_bin_sha256": SOURCE_SHA256,
        "translation_json_sha256": TRANSLATION_SHA256,
        "record_path": RECORD_PATH,
        "selector_index": TARGET_SELECTOR,
        "translated_entry_count": TARGET_ENTRY_COUNT,
        "question_count": 20,
        "answer_count": 80,
        "source_stored_sha256": source_stored_sha256,
        "input_master_stored_sha256": master_stored_sha256,
        "patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
        "patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
        "input_master_record_size": master_stored.len(),
        "compressed_size_before_padding": unpadded_compressed_size,
        "current_selector6_message_bytes": current_selector6_message_bytes,
        "translated_selector6_message_bytes": translated_selector6_message_bytes,
        "selector6_growth_bytes":
            translated_selector6_message_bytes - current_selector6_message_bytes,
        "arena_capacity_bytes": arena_capacity_bytes,
        "arena_used_bytes": arena_used_bytes,
        "arena_spare_bytes": arena_spare_bytes,
        "installed_visible_ascii_glyph_count": glyph_report.len(),
        "space_uses_blank_extension_slot": needs_space,
        "palette_indices": {
            "clear": clear,
            "outline": outline,
            "fill": fill,
        },
        "glyphs": glyph_report,
        "other_banks_preserved": true,
        "only_mgk04_replaced": true,
        "readback_verified": true,
        "disc_length_preserved": true,
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "output_sha256": output_sha256,
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("LIVE_MGK04_QUIZ_V16_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("SOURCE_MGK04_STORED_SHA256={source_stored_sha256}");
    eprintln!(
        "PATCHED_MGK04_STORED_SHA256={}",
        crate::pipeline::sha256_bytes(&patched_stored)
    );
    eprintln!("TRANSLATED_ENTRIES={TARGET_ENTRY_COUNT}");
    eprintln!("INSTALLED_VISIBLE_ASCII_GLYPHS={}", glyph_report.len());
    eprintln!("CURRENT_SELECTOR6_MESSAGE_BYTES={current_selector6_message_bytes}");
    eprintln!("TRANSLATED_SELECTOR6_MESSAGE_BYTES={translated_selector6_message_bytes}");
    eprintln!(
        "SELECTOR6_GROWTH_BYTES={}",
        translated_selector6_message_bytes - current_selector6_message_bytes
    );
    eprintln!("ARENA_USED_BYTES={arena_used_bytes}");
    eprintln!("ARENA_CAPACITY_BYTES={arena_capacity_bytes}");
    eprintln!("ARENA_SPARE_BYTES={arena_spare_bytes}");
    eprintln!("COMPRESSED_SIZE={unpadded_compressed_size}");
    eprintln!("FIXED_RECORD_SIZE={}", master_stored.len());
    eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
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
    Write-Host "[1/2] Building all 20 questions + 80 answers into MGK04 bank 6..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_live_mgk04_quiz_v16",
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

if (-not (Test-Path $OutputBin)) { Fail "v15b output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v15b output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v15 report JSON missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "LIVE MGK04 QUIZ ENGLISH v16 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Translated entries: {0}" -f $Report.translated_entry_count)
Write-Host ("Questions: {0}" -f $Report.question_count)
Write-Host ("Answers: {0}" -f $Report.answer_count)
Write-Host ("Installed ASCII glyphs: {0}" -f $Report.installed_visible_ascii_glyph_count)
Write-Host ("Selector 6 growth: +{0} bytes" -f $Report.selector6_growth_bytes)
Write-Host ("Shared arena bytes used: {0} / {1} (spare {2})" -f $Report.arena_used_bytes, $Report.arena_capacity_bytes, $Report.arena_spare_bytes)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "Scope:" -ForegroundColor Cyan
Write-Host "  DAT2/MGK04.BIZ selector 6 entries 0-99 translated"
Write-Host "  20 questions + 80 answers"
Write-Host "  Other MGK04 dialogue message payloads preserved; banks safely repacked"
Write-Host "  v15b MGK10 quiz work + all earlier layers preserved"
Write-Host ""
Write-Host "The static Japanese QUESTION label is NOT part of this text-bank patch." -ForegroundColor Yellow
Write-Host "Live-test the quiz bank first; we will sweep the remaining fixed quiz UI afterward." -ForegroundColor Yellow

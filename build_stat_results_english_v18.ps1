[CmdletBinding()]
param(
    [string]$RecoveryRoot = "",
    [string]$MasterBin = "",
    [string]$SourceBin = "",
    [string]$UpstreamRoot = "",
    [string]$WorkRoot = "",
    [switch]$CheckOnly
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
function FullPath([string]$Path) { return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path) }
function Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Assert-FreeSpace([string]$OutputPath, [long]$DiscBytes, [string]$TargetPath) {
    $Budgets = @{}
    foreach ($Need in @(@{Path=$OutputPath;Bytes=$DiscBytes+32MB},@{Path=$TargetPath;Bytes=4GB})) {
        $Root = [IO.Path]::GetPathRoot((FullPath $Need.Path))
        if (-not $Budgets.ContainsKey($Root)) { $Budgets[$Root] = [long]0 }
        $Budgets[$Root] += [long]$Need.Bytes
    }
    foreach ($Root in $Budgets.Keys) {
        $Drive = [IO.DriveInfo]::new($Root)
        $Available = [long]$Drive.AvailableFreeSpace
        Write-Host ("Drive {0}: {1:N2} GiB free; {2:N2} GiB required." -f $Root, ($Available/1GB), ($Budgets[$Root]/1GB))
        if ($Available -lt $Budgets[$Root]) { throw "Not enough free space. Choose -WorkRoot / CARGO_TARGET_DIR on a roomier drive. No game or source file has been changed." }
    }
}
if (-not $RecoveryRoot) { $RecoveryRoot = Join-Path $env:USERPROFILE "JG2-Recovery-v1" }
$RecoveryRoot = FullPath $RecoveryRoot
if (-not $UpstreamRoot) { $UpstreamRoot = Join-Path $RecoveryRoot "project/upstream" }
$UpstreamRoot = FullPath $UpstreamRoot
if (-not $SourceBin) { $SourceBin = Join-Path $UpstreamRoot "roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" }
if (-not $MasterBin) {
    $StatePath = Join-Path $RecoveryRoot "recovery-state.json"
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { throw "Recovery state missing. Pass -RecoveryRoot or -MasterBin with the working v17h BIN." }
    $State = Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json
    if (-not $State.v17h_bin) { throw "Recovery state has no completed v17h BIN. Pass -MasterBin explicitly." }
    $MasterBin = [string]$State.v17h_bin
}
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/stat-results-v18-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/dialogue_audit/name_entry_input_tests.rs"
$ExpectedMasterHash = "2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "name_entry_input_tests.pre-v18.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v18.log"
Write-Host "Justice Gakuen English Project - STAT RESULTS ENGLISH v18" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v17h master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }
$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_STAT_RESULTS_V18")) {
    throw "A previous v18 source injection remains. Restore name_entry_input_tests.pre-v18.rs.bak from that run's candidate folder before retrying."
}
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host "Verified original and v17h images, source availability, output ownership, and free space." -ForegroundColor Green
if ($CheckOnly) { Write-Host "Preflight passed. No files changed." -ForegroundColor Green; return }
$Rust = @'
// ENGLISH_PROJECT_STAT_RESULTS_V18
mod english_stat_v18 {
    use anyhow::{Context, Result, ensure};
    use serde_json::{Value, json};
    use std::{collections::BTreeSet, fs, path::PathBuf};
    use super::super::{atlas, parser, tokens};
    use crate::pipeline::{sha256_bytes, sha256_file};

    const MASTER_HASH: &str = "2ff4d83cca04a22a217883ac9c29b3e2fa9c5c4796d9661db3f95d9acd92149a";
    const SOURCE_HASH: &str = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
    const SOURCE_RECORD_HASH: &str = "0558890edf197093859d9e4d38a123592f0f793d33c47c13b70e9bbad94a3e30";
    const MASTER_RECORD_HASH: &str = "460f998df47eab3a4e82425afc352badca543a66f4dbc7a82e2056657cf1c70d";
    const MGAME_HASH: &str = "e8885452773fcf91bef4b85b2363a37d07547ab3c04b463c92c658d66cc1492f";
    const RECORD: &str = "DAT2/MGK04.BIZ";
    const ARENA: usize = 0x31000;
    const SCRIPT: usize = 0x4a000;
    const SPACE: u16 = 0x2ea;
    const NAMES: [&str; 9] = ["ATK", "DEF", "STAM", "GUTS", "POT", "SPEED", "PUNCH", "KICK", "INT"];
    const NATIVE_CELLS: [usize; 9] = [3, 3, 2, 2, 4, 4, 3, 3, 2];
    const ARROWS: [u16; 9] = [88, 88, 68, 68, 108, 108, 88, 88, 68];

    fn code(ch: char) -> Result<u16> {
        // Existing Arial cells installed by the exact v16 quiz layer. No font
        // or source-bound translation packet is required for this patch.
        "ABCDEFGHIJKLMNOPRSTUVWYZ".chars().position(|c| c == ch)
            .map(|i| 0x2f6 + i as u16).with_context(|| format!("unsupported letter {ch}"))
    }
    fn words(bytes: &[u8]) -> Vec<u16> {
        bytes.chunks_exact(2).map(|b| u16::from_le_bytes([b[0], b[1]])).collect()
    }
    fn encode(mut values: Vec<u16>) -> Vec<u8> {
        if values.len() % 2 != 0 { values.push(0); }
        values.into_iter().flat_map(u16::to_le_bytes).collect()
    }
    fn cell(data: &[u8], pixel: usize, code: u16) -> Vec<u8> {
        let at = pixel + usize::from(code) * 200;
        data[at..at+200].iter().flat_map(|b| [b & 15, b >> 4]).collect()
    }
    fn install(data: &mut [u8], pixel: usize, code: u16, pixels: &[u8]) -> Result<()> {
        ensure!(pixels.len() == 400 && pixels.iter().all(|p| *p < 16), "invalid glyph pixels");
        let at = pixel + usize::from(code) * 200;
        ensure!(data[at..at+200].iter().all(|b| *b == 0), "new glyph would overwrite existing artwork");
        for (i, pair) in pixels.chunks_exact(2).enumerate() { data[at+i] = pair[0] | pair[1] << 4; }
        Ok(())
    }
    struct Built { stored: Vec<u8>, decoded: Vec<u8>, report: Value }

    fn patch_record(master: &[u8], source: &[u8], mgame: &[u8]) -> Result<Built> {
        ensure!(sha256_bytes(master) == MASTER_RECORD_HASH, "working MGK04 record hash changed");
        ensure!(sha256_bytes(source) == SOURCE_RECORD_HASH, "original MGK04 record hash changed");
        ensure!(sha256_bytes(mgame) == MGAME_HASH, "working MGAME record hash changed");
        ensure!(words(&mgame[0x21d4..0x21e6]) == ARROWS, "native arrow table changed");
        ensure!(sha256_bytes(&mgame[0x1a128..0x1a154]) == "c32e6247055dcda3ce65f1928d550e0bc0f753fed0b8ebc33b87b43cfec54116", "arrow consumer changed");
        let original = crate::compression::decompress(source, true)?;
        let current = crate::compression::decompress(master, true)?;
        let mut patched = current.clone();
        let before = parser::parse_dialogue_banks(&current)?;
        let original_banks = parser::parse_dialogue_banks(&original)?;
        let bank = before.iter().find(|b| b.selector_index == 2).context("selector 2 missing")?;
        let source_bank = original_banks.iter().find(|b| b.selector_index == 2).context("source selector 2 missing")?;
        ensure!(bank.messages.len() == 170 && source_bank.messages.len() == 170, "selector 2 population changed");
        let at = atlas::parse_dialogue_atlas(&current)?;
        ensure!(at.pixel_data_offset == 384 && at.fixed_cell_count == 746 && at.addressable_slot_count == 1001, "font geometry changed");
        ensure!(cell(&current, at.pixel_data_offset, SPACE).iter().all(|p| *p == 0), "English space is not blank");
        let mut used = BTreeSet::new();
        for b in &before {
            for m in &b.messages {
                for t in tokens::tokenize_dialogue_message(&words(&m.data), at.fixed_cell_count, at.addressable_slot_count)?.tokens {
                    if matches!(t.kind, tokens::DialogueTokenKind::FixedGlyph | tokens::DialogueTokenKind::RuntimeExtensionGlyph) {
                        used.insert(t.code);
                    }
                }
            }
        }
        for c in 0..at.addressable_slot_count {
            if cell(&current, at.pixel_data_offset, c as u16).iter().any(|p| *p != 0) { used.insert(c as u16); }
        }
        // Allocate only after every existing nonzero or referenced glyph, rather
        // than taking holes that another earlier translation might reserve.
        let first = usize::from(*used.last().context("font has no used slots")?) + 1;
        let required = 1 + NATIVE_CELLS.iter().map(|n| n + 1).sum::<usize>();
        ensure!(first + required <= at.addressable_slot_count, "not enough trailing empty glyph slots");
        let mut next = first as u16;
        let punctuation = next; next += 1;
        // A matching exclamation mark uses the existing Arial I stem and dot.
        // Keep their original palette indices and baseline; separate the stem
        // and dot with one clear row. No external font rasterizer is involved.
        let mut exclamation = vec![0; 400];
        let stem = cell(&current, at.pixel_data_offset, code('I')?);
        let dot = cell(&current, at.pixel_data_offset, 0x2ee);
        exclamation[4*20..11*20].copy_from_slice(&stem[4*20..11*20]);
        exclamation[11*20..12*20].copy_from_slice(&stem[15*20..16*20]);
        exclamation[13*20..16*20].copy_from_slice(&dot[13*20..16*20]);
        install(&mut patched, at.pixel_data_offset, punctuation, &exclamation)?;
        let mut labels = Vec::new();
        let mut layout = Vec::new();
        for (stat, name) in NAMES.iter().enumerate() {
            let count = NATIVE_CELLS[stat] + 1;
            let width = count * 20;
            let mut letters = Vec::new();
            for ch in name.chars() {
                let pixels = cell(&current, at.pixel_data_offset, code(ch)?);
                let left = (0..20).find(|x| (0..20).any(|y| pixels[y*20+x] != 0)).context("blank ASCII letter")?;
                let right = (0..20).rev().find(|x| (0..20).any(|y| pixels[y*20+x] != 0)).unwrap();
                ensure!(pixels.iter().all(|p| [0, 4, 14].contains(p)), "existing ASCII palette changed");
                letters.push((pixels, left, right));
            }
            let ink_width = letters.iter().map(|(_, l, r)| r-l+1).sum::<usize>() + letters.len()-1;
            let ink_right = usize::from(ARROWS[stat]) - 16;
            ensure!(ink_width <= ink_right && ink_right <= width, "English label cannot clear the native arrow");
            let mut x = ink_right - ink_width;
            let mut strip = vec![0; width * 20];
            for (pixels, left, right) in letters {
                for y in 0..20 { for gx in left..=right { strip[y*width+x+gx-left] = pixels[y*20+gx]; } }
                x += right-left+2;
            }
            let mut label = Vec::new();
            for part in 0..count {
                let mut pixels = Vec::with_capacity(400);
                for y in 0..20 { pixels.extend_from_slice(&strip[y*width+part*20..y*width+(part+1)*20]); }
                install(&mut patched, at.pixel_data_offset, next, &pixels)?;
                label.push(next); next += 1;
            }
            // Keep the original pre-arrow column count. One extra blank after
            // the two protected padding controls gives 24px right clearance.
            let result_x = (NATIVE_CELLS[stat]+5)*20;
            ensure!(result_x - (usize::from(ARROWS[stat])+48) >= 12, "result overlaps arrow");
            ensure!(result_x+11*20 <= 400, "stat message exceeds the native 400px row");
            layout.push(json!({"stat":name,"arrow_x":ARROWS[stat],"arrow_width":48,"label_ink_right_exclusive":ink_right,"label_gap":16,"result_x":result_x,"result_gap":result_x-usize::from(ARROWS[stat])-48,"row_right":result_x+220,"glyph_codes":label}));
            labels.push(label);
        }
        ensure!(usize::from(next) == first+required, "glyph allocation count mismatch");
        let mut replacements = Vec::new();
        for direction in 0..2 {
            for stat in 0..9 {
                let index = 34 + direction*9 + stat;
                ensure!(bank.messages[index].data == source_bank.messages[index].data, "stat message {index} is no longer original");
                let source_tokens = tokens::tokenize_dialogue_message(&words(&bank.messages[index].data), at.fixed_cell_count, at.addressable_slot_count)?;
                let control = source_tokens.tokens.iter().filter(|t| !matches!(t.kind, tokens::DialogueTokenKind::FixedGlyph | tokens::DialogueTokenKind::RuntimeExtensionGlyph)).map(|t| (t.code,t.arguments.clone())).collect::<Vec<_>>();
                ensure!(control == [(0x3003,vec![4]),(0x3003,vec![255]),(0x061e,vec![]),(0x061e,vec![]),(0x3001,vec![])], "stat control structure changed");
                let mut w = vec![0x3003,4]; w.extend_from_slice(&labels[stat]);
                w.extend_from_slice(&[0x3003,255,SPACE,0x061e,0x061e,SPACE]);
                let suffix = if direction == 0 {"INCREASED"} else {"DECREASED"};
                for ch in suffix.chars() { w.push(code(ch)?); }
                w.extend_from_slice(&[punctuation,punctuation,0x3001]);
                let data = encode(w);
                let parsed = tokens::tokenize_dialogue_message(&words(&data), at.fixed_cell_count, at.addressable_slot_count)?;
                let after_control = parsed.tokens.iter().filter(|t| !matches!(t.kind, tokens::DialogueTokenKind::FixedGlyph | tokens::DialogueTokenKind::RuntimeExtensionGlyph)).map(|t| (t.code,t.arguments.clone())).collect::<Vec<_>>();
                ensure!(after_control == control, "protected stat controls changed");
                replacements.push(data);
            }
        }
        patched[ARENA..SCRIPT].fill(0);
        let mut cursor = ARENA+32;
        let mut expected = Vec::new();
        for b in &before {
            let mut pointers = Vec::new(); let mut expected_bank = Vec::new();
            for (i,m) in b.messages.iter().enumerate() {
                let data = if b.selector_index == 2 && (34..52).contains(&i) { &replacements[i-34] } else { &m.data };
                ensure!(cursor%4 == 0 && data.len()%4 == 0 && cursor+data.len() <= SCRIPT, "message arena overflow/alignment");
                pointers.push(cursor); patched[cursor..cursor+data.len()].copy_from_slice(data); cursor += data.len();
                expected_bank.push(data.clone());
            }
            let table = cursor;
            for offset in pointers { ensure!(cursor+4 <= SCRIPT, "pointer table overflow"); patched[cursor..cursor+4].copy_from_slice(&(0x800d0000+offset as u32).to_le_bytes()); cursor+=4; }
            ensure!(cursor+4 <= SCRIPT, "terminator overflow"); patched[cursor..cursor+4].copy_from_slice(&u32::MAX.to_le_bytes()); cursor+=4;
            let selector = ARENA+b.selector_index*4;
            patched[selector..selector+4].copy_from_slice(&(0x800d0000+table as u32).to_le_bytes());
            expected.push(expected_bank);
        }
        let after = parser::parse_dialogue_banks(&patched)?;
        ensure!(after.len() == before.len(), "bank count changed");
        for ((new,old),messages) in after.iter().zip(&before).zip(&expected) {
            ensure!(new.selector_index == old.selector_index && new.messages.len() == old.messages.len(), "bank shape changed");
            for (i,(message,wanted)) in new.messages.iter().zip(messages).enumerate() {
                ensure!(message.data == *wanted, "parse-back mismatch in bank {} entry {i}",new.selector_index);
                if new.selector_index != 2 || !(34..52).contains(&i) { ensure!(message.data == old.messages[i].data,"unrelated dialogue changed"); }
            }
        }
        let glyph_start = at.pixel_data_offset + first*200;
        let glyph_end = at.pixel_data_offset + usize::from(next)*200;
        for (offset,(&a,&b)) in current.iter().zip(&patched).enumerate() {
            ensure!(a == b || (glyph_start..glyph_end).contains(&offset) || (ARENA..SCRIPT).contains(&offset), "decoded change escaped owned ranges at {offset:x}");
        }
        let profile = crate::paged_compression::source_paged_compression_profile(master)?;
        let compressed = crate::paged_compression::compress_page_safe_image_in_slot(&patched, profile, master.len())?;
        ensure!(crate::compression::decompress(&compressed, false)? == patched, "compression round trip failed");
        let length = compressed.len(); let mut stored = compressed; stored.resize(master.len(),0);
        ensure!(crate::compression::decompress(&stored, true)? == patched, "padded record round trip failed");
        ensure!(sha256_bytes(&stored) == "91ca0e81829fb578d41797854718590e0f05e29b1325b6a1675e9df3a4584fa0", "patched record differs from the validated v18 candidate");
        let report = json!({"kind":"Justice Gakuen 2 MGK04 stat results English v18","record_path":RECORD,"source_record_sha256":SOURCE_RECORD_HASH,"master_record_sha256":MASTER_RECORD_HASH,"patched_record_sha256":sha256_bytes(&stored),"patched_decoded_sha256":sha256_bytes(&patched),"translated_entries":18,"selector":2,"entry_start":34,"entry_end_inclusive":51,"glyph_start":first,"glyph_end_exclusive":next,"installed_glyph_cells":required,"compressed_bytes":length,"record_bytes":master.len(),"arena_used_bytes":cursor-(ARENA+32),"arena_capacity_bytes":SCRIPT-(ARENA+32),"other_messages_preserved":true,"quiz_100_entries_preserved":true,"script_and_later_preserved":true,"mgame_and_arrows_unchanged":true,"label_layout":layout});
        Ok(Built {stored,decoded:patched,report})
    }

    fn output_dir(variable: &str) -> Result<PathBuf> {
        let path = PathBuf::from(std::env::var(variable).with_context(|| format!("{variable} missing"))?);
        ensure!(!path.exists(), "output directory already exists: {}",path.display());
        fs::create_dir_all(&path)?; Ok(path)
    }
    #[test]
    fn english_project_stat_results_v18() -> Result<()> {
        let master = PathBuf::from(std::env::var("JG2_V18_MASTER")?);
        let source = PathBuf::from(std::env::var("JG2_V18_SOURCE")?);
        ensure!(sha256_file(&master)? == MASTER_HASH, "v17h master SHA mismatch");
        ensure!(sha256_file(&source)? == SOURCE_HASH, "original disc SHA mismatch");
        let (_,current) = crate::disc::rebuild::read_record(&master,RECORD)?;
        let (_,original) = crate::disc::rebuild::read_record(&source,RECORD)?;
        let (_,mgame) = crate::disc::rebuild::read_record(&master,"DAT1/MGAME.BIN")?;
        let mut built = patch_record(&current,&original,&mgame)?;
        let out = output_dir("JG2_V18_OUTPUT")?;
        let bin = out.join("justice-gakuen2-stat-results-v18.bin");
        let cue = out.join("justice-gakuen2-stat-results-v18.cue");
        let replaced = crate::disc::rebuild::copy_and_replace_record(&master,&bin,RECORD,&built.stored)?;
        ensure!(crate::disc::rebuild::read_record(&bin,RECORD)?.1 == built.stored,"disc record readback failed");
        let (changed,output_hash) = crate::disc::rebuild::compare_and_hash_images(&master,&bin)?;
        ensure!(!changed.is_empty() && changed.iter().all(|lba| replaced.target_lbas.contains(lba)),"changed sectors escaped MGK04");
        let mut track = crate::disc::RawTrack::open(&bin)?;
        for lba in &changed { ensure!(crate::disc::mode2::verify(&track.raw_sector(*lba)?), "rebuilt sector failed EDC/ECC at {lba}"); }
        ensure!(sha256_file(&master)? == MASTER_HASH && sha256_file(&source)? == SOURCE_HASH,"input image changed during build");
        fs::write(&cue,"FILE \"justice-gakuen2-stat-results-v18.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
        built.report["master_sha256"] = json!(MASTER_HASH); built.report["source_sha256"] = json!(SOURCE_HASH);
        built.report["output_sha256"] = json!(output_hash); built.report["changed_lbas"] = json!(changed);
        built.report["changed_sector_count"] = json!(changed.len()); built.report["cue"] = json!(cue.display().to_string());
        fs::write(out.join("stat-results-v18-report.json"),serde_json::to_vec_pretty(&built.report)?)?;
        eprintln!("STAT_RESULTS_V18_COMPLETE=1\nOUTPUT_SHA256={output_hash}\nCHANGED_RAW_SECTORS={}\nCOMPRESSED_SIZE={}\nCUE={}",changed.len(),built.report["compressed_bytes"],cue.display());
        Ok(())
    }
    #[test]
    #[ignore = "requires the private hash-verified stat-probe export"]
    fn stat_results_v18_record_fixture() -> Result<()> {
        let root = PathBuf::from(std::env::var("JG2_V18_FIXTURE")?);
        let built = patch_record(&fs::read(root.join("v17h/DAT2/MGK04.BIZ"))?,&fs::read(root.join("original/DAT2/MGK04.BIZ"))?,&fs::read(root.join("v17h/DAT1/MGAME.BIN"))?)?;
        let out = output_dir("JG2_V18_OUTPUT")?;
        fs::write(out.join("MGK04.BIZ"),&built.stored)?;
        fs::write(out.join("MGK04.decoded"),&built.decoded)?;
        fs::write(out.join("report.json"),serde_json::to_vec_pretty(&built.report)?)?;
        eprintln!("{}",serde_json::to_string_pretty(&built.report)?); Ok(())
    }
}
'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V18_MASTER","JG2_V18_SOURCE","JG2_V18_OUTPUT")) {
    $SavedEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name,"Process")
}
[IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
$BackupStream = [IO.File]::Open($Backup,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $BackupStream.Write($OriginalRust,0,$OriginalRust.Length) } finally { $BackupStream.Dispose() }
if ((Hash $Backup) -ne $OriginalRustHash) { throw "Source backup verification failed; source was not edited." }
Write-Host ("Exact source backup: " + $Backup)
$Utf8 = [Text.UTF8Encoding]::new($false)
$Append = $Utf8.GetBytes("`n" + $Rust + "`n")
$Injected = New-Object byte[] ($OriginalRust.Length + $Append.Length)
[Array]::Copy($OriginalRust,0,$Injected,0,$OriginalRust.Length)
[Array]::Copy($Append,0,$Injected,$OriginalRust.Length,$Append.Length)
try {
    if (-not $env:CARGO_HOME -and (Test-Path -LiteralPath (Join-Path $RecoveryRoot "cargo-cache") -PathType Container)) {
        $env:CARGO_HOME = Join-Path $RecoveryRoot "cargo-cache"
    }
    $env:CARGO_TARGET_DIR = $TargetPath
    $env:RUSTUP_TOOLCHAIN = "1.98.0"
    $env:JG2_V18_MASTER = $MasterBin
    $env:JG2_V18_SOURCE = $SourceBin
    $env:JG2_V18_OUTPUT = $BuildDir
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building 18 English stat messages and verifying the candidate..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_stat_results_v18 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v18 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "stat-results-v18-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-stat-results-v18.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.translated_entries -ne 18 -or -not $Report.quiz_100_entries_preserved -or -not $Report.mgame_and_arrows_unchanged) { throw "Final report scope verification failed." }
if ((Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output hash differs from the build report." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "STAT RESULTS ENGLISH v18 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host ("Translated messages: " + $Report.translated_entries + " (9 increases + 9 decreases)")
Write-Host ("Changed raw sectors: " + $Report.changed_sector_count)
Write-Host ("MGK04 compressed bytes: {0} / {1}" -f $Report.compressed_bytes,$Report.record_bytes)
Write-Host "Native arrows, game logic, all 100 quiz entries, and earlier layers preserved."
Write-Host ""
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v17h. Boot this new CUE and replay the quiz to test the stat-result text and arrow spacing."
Write-Host "This candidate translates MGK04's stat messages; other scene banks may still contain Japanese."

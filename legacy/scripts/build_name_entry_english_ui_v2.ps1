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

function Norm([string]$Text) {
    if ($null -eq $Text) { return "" }
    return (($Text -replace '\s+', '') -replace '　', '')
}

function Get-AppEnglish($Entry) {
    $src = [string]$Entry.source_text
    $id = ([string]$Entry.id).ToLowerInvariant()
    $n = Norm $src

    # Source-text first: these remain stable even if target IDs came from an
    # earlier Korean asset authoring pass.
    if ($n -match '入学願書') { return "ENROLLMENT FORM" }
    if ($n -match '受験日' -and $n -match '4月1日') { return "EXAM DATE 4/1" }
    if ($n -eq '受験日') { return "EXAM DATE" }
    if ($n -eq '4月1日') { return "4/1" }
    if ($n -eq '氏名') { return "NAME" }
    if ($n -eq '姓') { return "LAST" }
    if ($n -eq '名') { return "FIRST" }
    if ($n -match '呼び名') { return "NICKNAME" }
    if ($n -match '志望校') { return "SCHOOL" }
    if ($n -match '性別') { return "SEX" }
    if ($n -match '生.*月.*日' -or $n -match '生年月日') { return "BIRTH DATE" }
    if ($n -eq '月') { return "M" }
    if ($n -eq '日') { return "D" }
    if ($n -match '試験会場') { return "EXAM SITE" }
    if ($n -match '本学.*他会場') { return "CAMPUS (O) OTHER ( )" }
    if ($n -match '得意科目') { return "BEST SUBJECT" }
    if ($n -match '好きな言葉') { return "FAVORITE WORD" }
    if ($n -match '全て.*欄.*記入') { return "* COMPLETE ALL FIELDS" }

    # Defensive ID fallbacks.
    if ($id -match 'title|application|enrollment') { return "ENROLLMENT FORM" }
    if ($id -match 'exam.*date') { return "EXAM DATE" }
    if ($id -match 'family|surname|last') { return "LAST" }
    if ($id -match 'given|first') { return "FIRST" }
    if ($id -match 'nickname|call.*name') { return "NICKNAME" }
    if ($id -match 'school' -and $id -notmatch 'choice') { return "SCHOOL" }
    if ($id -match 'sex|gender') { return "SEX" }
    if ($id -match 'birth') { return "BIRTH DATE" }
    if ($id -match 'exam.*site|venue') { return "EXAM SITE" }
    if ($id -match 'subject') { return "BEST SUBJECT" }
    if ($id -match 'favorite.*word|phrase') { return "FAVORITE WORD" }
    if ($id -match 'note|instruction') { return "* COMPLETE ALL FIELDS" }

    return $null
}

function Get-ControlEnglish($Entry) {
    $src = [string]$Entry.source_text
    $id = ([string]$Entry.id).ToLowerInvariant()
    $n = Norm $src

    if ($n -eq 'ひらがな') { return "HIRA" }
    if ($n -eq 'カタカナ') { return "KATA" }
    if ($n -eq '英数') { return "A-Z" }
    if ($n -eq '削除') { return "DEL" }
    if ($n -eq '進む') { return "NEXT" }
    if ($n -eq '戻る') { return "BACK" }
    if ($n -eq '決定') { return "OK" }

    # ID fallbacks cover the tracked localized asset names too.
    if ($id -match 'hiragana|hangul') { return "HIRA" }
    if ($id -match 'katakana') { return "KATA" }
    if ($id -match 'latin|alpha|english|eisu') { return "A-Z" }
    if ($id -match 'delete') { return "DEL" }
    if ($id -match 'next|advance|forward') { return "NEXT" }
    if ($id -match 'back|return') { return "BACK" }
    if ($id -match 'confirm|decide|ok') { return "OK" }

    return $null
}

function Prepare-GraphicsJson(
    [string]$SourcePath,
    [string]$DestinationPath,
    [scriptblock]$Translator,
    [string]$Label
) {
    if (-not (Test-Path $SourcePath)) {
        Fail "Missing tracked graphics asset: $SourcePath"
    }

    $Obj = Get-Content $SourcePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $Obj.entries) {
        Fail "$Label JSON has no entries."
    }

    $Matched = New-Object System.Collections.Generic.List[object]
    $Unmatched = New-Object System.Collections.Generic.List[object]

    foreach ($Entry in @($Obj.entries)) {
        $English = & $Translator $Entry
        if ($null -ne $English) {
            $Entry.korean_text = [string]$English
            $Matched.Add($Entry)
            Write-Host (
                "  {0,-28} {1} -> {2}" -f
                ([string]$Entry.id),
                ([string]$Entry.source_text),
                ([string]$English)
            )
        }
        else {
            $Unmatched.Add($Entry)
        }
    }

    if ($Matched.Count -eq 0) {
        Fail "${Label}: no entries matched the English translation map."
    }

    # Only install entries we explicitly translated. Any unrelated tracked
    # Korean graphics remain byte-for-byte original Japanese in this pass.
    $Obj.entries = @($Matched)

    [System.IO.File]::WriteAllText(
        $DestinationPath,
        (($Obj | ConvertTo-Json -Depth 100) + [Environment]::NewLine),
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ("  Matched: {0}; deliberately untouched: {1}" -f $Matched.Count, $Unmatched.Count)
    if ($Unmatched.Count -gt 0) {
        Write-Host "  Untouched entries:" -ForegroundColor DarkGray
        foreach ($Entry in $Unmatched) {
            Write-Host (
                "    {0}: {1}" -f
                ([string]$Entry.id),
                ([string]$Entry.source_text)
            ) -ForegroundColor DarkGray
        }
    }

    return $Matched.Count
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$RustPath = Join-Path $Upstream "src\dialogue_audit\name_entry_font_build.rs"

$MasterBin = Join-Path $Upstream "work\english-mgk04-full-tutorial-v3\build\justice-gakuen2-mgk04-full-tutorial-v3.bin"
$ExpectedMasterHash = "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4"

$TrackedGraphics = Join-Path $Upstream "assets\dialogue\name-entry-graphics"
$TrackedApp = Join-Path $TrackedGraphics "application-form.json"
$TrackedControls = Join-Path $TrackedGraphics "candidate-controls.json"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-ui-v2"
$GraphicsRoot = Join-Path $WorkRoot "graphics"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-ui-v2.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-ui-v2.cue"
$ReportJson = Join-Path $BuildDir "name-entry-ui-v2-report.json"

$FontPath = "C:\Windows\Fonts\arial.ttf"

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY ENGLISH UI v2" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing name_entry_font_build.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing current MGK04 v3 English master BIN." }
if (-not (Test-Path $FontPath)) { Fail "Missing C:\Windows\Fonts\arial.ttf." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "Current English master hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $GraphicsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

Write-Host ""
Write-Host "[1/4] Preparing English application-form graphics..." -ForegroundColor Cyan
$AppCount = Prepare-GraphicsJson `
    $TrackedApp `
    (Join-Path $GraphicsRoot "application-form.json") `
    ${function:Get-AppEnglish} `
    "application form"

Write-Host ""
Write-Host "[2/4] Preparing English name-entry controls..." -ForegroundColor Cyan
$ControlCount = Prepare-GraphicsJson `
    $TrackedControls `
    (Join-Path $GraphicsRoot "candidate-controls.json") `
    ${function:Get-ControlEnglish} `
    "candidate controls"

if ($AppCount -lt 6) {
    Write-Host ""
    Write-Host "WARNING: fewer application-form entries matched than expected." -ForegroundColor Yellow
    Write-Host "The build will still proceed; unmatched form text remains original Japanese." -ForegroundColor Yellow
}
if ($ControlCount -lt 7) {
    Write-Host ""
    Write-Host "WARNING: fewer than all seven visible candidate-control labels matched." -ForegroundColor Yellow
    Write-Host "The build will still proceed; unmatched controls remain original Japanese." -ForegroundColor Yellow
}

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_NAME_ENTRY_UI_V2"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale English name-entry UI v1 injection already exists."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$GraphicsLiteral = $GraphicsRoot.Replace("\", "\\")
$FontLiteral = $FontPath.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_NAME_ENTRY_UI_V2
#[cfg(test)]
mod english_name_entry_ui_v2 {
    use super::*;
    use anyhow::{Context, Result, ensure};
    use std::fs;
    use std::path::Path;

    const INPUT: &str = "$MasterLiteral";
    const INPUT_SHA256: &str =
        "30cdcc7cdbc1a21818b65272ac50e7baebc245f0505c83d03dfb2c00db713ac4";
    const GRAPHICS_ROOT: &str = "$GraphicsLiteral";
    const FONT: &str = "$FontLiteral";

    #[test]
    fn english_name_entry_ui_v2() -> Result<()> {
        let worker = std::thread::Builder::new()
            .name("english-name-entry-ui-v2-large-stack".to_string())
            .stack_size(64 * 1024 * 1024)
            .spawn(run_patch)?;
        match worker.join() {
            Ok(result) => result,
            Err(payload) => std::panic::resume_unwind(payload),
        }
    }

    fn run_patch() -> Result<()> {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let input = Path::new(INPUT);
        ensure!(input.is_file(), "English master BIN is missing");
        ensure!(
            crate::pipeline::sha256_file(input)? == INPUT_SHA256,
            "English master BIN hash changed"
        );

        let output_root = root.join("work/english-name-entry-ui-v2");
        let build_dir = output_root.join("build");
        fs::create_dir_all(&build_dir)?;
        let output_bin = build_dir.join("justice-gakuen2-name-entry-ui-v2.bin");
        let output_cue = build_dir.join("justice-gakuen2-name-entry-ui-v2.cue");
        let report_path = build_dir.join("name-entry-ui-v2-report.json");

        let (_, source_overlay) =
            crate::disc::rebuild::read_record(input, "DAT1/MGENT.BIN")?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_overlay)
                == "eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a",
            "MGENT.BIN changed unexpectedly"
        );

        let (_, source_stored) =
            crate::disc::rebuild::read_record(input, NAME_ENTRY_FONT_PATH)?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_stored) == SOURCE_STORED_SHA256,
            "MA_ENT.BIZ stored source changed"
        );

        let source_decoded = crate::compression::decompress(&source_stored, true)?;
        ensure!(
            crate::pipeline::sha256_bytes(&source_decoded) == SOURCE_DECODED_SHA256,
            "MA_ENT.BIZ decoded source changed"
        );
        ensure!(
            source_decoded.len() == SOURCE_DECODED_SIZE,
            "MA_ENT.BIZ decoded size changed"
        );

        let mut patched_decoded = source_decoded.clone();
        let graphics_root = Path::new(GRAPHICS_ROOT);
        let font = Path::new(FONT);
        ensure!(graphics_root.is_dir(), "English graphics directory is missing");
        ensure!(font.is_file(), "fixed graphics font is missing");

        let source = NameEntryFixedGraphicsSource {
            path: NAME_ENTRY_FONT_PATH,
            decoded_sha256: SOURCE_DECODED_SHA256,
        };

        eprintln!("name-entry-ui: installing application form");
        let app = install_name_entry_fixed_graphics(
            &source_decoded,
            &mut patched_decoded,
            graphics_root,
            font,
            source,
            application_form_spec(),
            &[],
        )?;

        eprintln!("name-entry-ui: installing candidate controls");
        let controls = install_name_entry_fixed_graphics(
            &source_decoded,
            &mut patched_decoded,
            graphics_root,
            font,
            source,
            candidate_controls_spec(),
            &[],
        )?;

        ensure!(
            patched_decoded != source_decoded,
            "English fixed graphics changed no MA_ENT bytes"
        );

        // The keyboard character atlas/code/navigation data is intentionally
        // untouched in this pass. Only JSON-declared fixed text cells are
        // allowed to differ.
        let source_profile =
            crate::paged_compression::source_paged_compression_profile(&source_stored)?;
        let reencoded =
            crate::paged_compression::compress_page_safe_image(&patched_decoded, source_profile)?;
        ensure!(
            crate::compression::decompress(&reencoded, false)? == patched_decoded,
            "MA_ENT page-safe compression roundtrip changed decoded data"
        );
        ensure!(
            reencoded.len() <= source_stored.len(),
            "English MA_ENT.BIZ exceeds the fixed source record"
        );
        let unpadded_size = reencoded.len();

        let mut patched_stored = reencoded;
        patched_stored.resize(source_stored.len(), 0);
        ensure!(
            crate::compression::decompress(&patched_stored, true)? == patched_decoded,
            "padded English MA_ENT.BIZ changed decoded data"
        );

        eprintln!("name-entry-ui: replacing only DAT2/MA_ENT.BIZ");
        let replacements = [crate::disc::rebuild::FixedRecordReplacement {
            path: NAME_ENTRY_FONT_PATH,
            data: &patched_stored,
        }];
        let rebuilt =
            crate::disc::rebuild::copy_and_replace_records(input, &output_bin, &replacements)?;
        ensure!(rebuilt.len() == 1, "disc rebuild replaced more than MA_ENT.BIZ");

        let (_, readback) =
            crate::disc::rebuild::read_record(&output_bin, NAME_ENTRY_FONT_PATH)?;
        ensure!(readback == patched_stored, "MA_ENT.BIZ readback differs");
        ensure!(
            crate::compression::decompress(&readback, true)? == patched_decoded,
            "MA_ENT.BIZ decoded readback differs"
        );
        ensure!(
            fs::metadata(input)?.len() == fs::metadata(&output_bin)?.len(),
            "disc image length changed"
        );

        let (changed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(input, &output_bin)?;
        ensure!(!changed_lbas.is_empty(), "English UI patch changed no sectors");
        ensure!(
            changed_lbas.iter().all(|lba| {
                rebuilt.iter().any(|record| record.target_lbas.contains(lba))
            }),
            "English UI patch changed sectors outside MA_ENT.BIZ"
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

        let report = serde_json::json!({
            "kind": "Justice Gakuen 2 English name-entry fixed UI v2",
            "input_bin_sha256": INPUT_SHA256,
            "output_bin_sha256": output_sha256,
            "changed_sector_count": changed_lbas.len(),
            "ma_ent_source_stored_sha256": SOURCE_STORED_SHA256,
            "ma_ent_source_decoded_sha256": SOURCE_DECODED_SHA256,
            "ma_ent_patched_stored_sha256": crate::pipeline::sha256_bytes(&patched_stored),
            "ma_ent_patched_decoded_sha256": crate::pipeline::sha256_bytes(&patched_decoded),
            "ma_ent_unpadded_size": unpadded_size,
            "application_form": app,
            "candidate_controls": controls,
            "mgent_unchanged": true,
            "keyboard_character_grid_unchanged": true,
            "readback_verified": true,
            "output_cue": output_cue.display().to_string()
        });
        let mut report_bytes = serde_json::to_vec_pretty(&report)?;
        report_bytes.push(b'\n');
        fs::write(&report_path, report_bytes)?;

        eprintln!("NAME_ENTRY_UI_COMPLETE=1");
        eprintln!("OUTPUT_SHA256={output_sha256}");
        eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
        eprintln!("CUE={}", output_cue.display());

        Ok(())
    }
}

"@

$Succeeded = $false
try {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Write-Host ""
    Write-Host "[3/4] Building source-bound English MA_ENT.BIZ..." -ForegroundColor Cyan

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_name_entry_ui_v2",
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
        $RustPath,
        $OriginalRust,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not $Succeeded) { Fail "English name-entry UI build did not complete." }
if (-not (Test-Path $OutputBin)) { Fail "Output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "Output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "Build report missing." }

Write-Host ""
Write-Host "[4/4] Verifying final output hash/report..." -ForegroundColor Cyan
$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()
if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NAME ENTRY ENGLISH UI v2 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "This build preserves MGENT.BIN and the 0-9/A-Z/a-z keyboard grid." -ForegroundColor Green
Write-Host "Only source-bound fixed UI cells in MA_ENT.BIZ are rewritten." -ForegroundColor Green

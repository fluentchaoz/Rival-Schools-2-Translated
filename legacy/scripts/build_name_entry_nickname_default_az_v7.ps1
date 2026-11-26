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
        Fail ("{0} failed with exit code {1}" -f $Command, $LASTEXITCODE)
    }
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"
$RustPath = Join-Path $Upstream "src\dialogue_audit\name_entry_input_tests.rs"

$MasterBin = Join-Path $Upstream "work\english-name-entry-default-az-v6\build\justice-gakuen2-name-entry-default-az-v6.bin"
$ExpectedMasterHash = "e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-nickname-default-az-v7"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-nickname-default-az-v7.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-nickname-default-az-v7.cue"
$ReportJson = Join-Path $BuildDir "name-entry-nickname-default-az-v7-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - NICKNAME DEFAULT A-Z v7" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing live-tested v6 candidate BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v6 input hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_NICKNAME_DEFAULT_AZ_V7"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v7 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_NICKNAME_DEFAULT_AZ_V7
#[test]
fn english_project_nickname_default_az_v7() -> anyhow::Result<()> {
    use anyhow::{Context, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    const INPUT: &str = "$MasterLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";

    const INPUT_SHA256: &str =
        "e3808a7bef6c6529e45b29963895a6e45a26dd7c30b031be928fcdb4fa98a09f";
    const MGENT_PATH: &str = "DAT1/MGENT.BIN";
    const MGENT_V6_SHA256: &str =
        "93aee308f5db552b97482b5f2c91f95ae2246849965334d5c47b2ecf54d15751";
    const MGENT_SIZE: usize = 36_796;

    // Nickname-specific page initializer:
    //   1fa4: addiu v0, zero, 1
    //   1fa8: sb    v0, 9(s0)
    //   1fac: addiu v0, zero, 2
    //
    // Change only the immediate at 1fa4 from 1 to 2. This makes nickname
    // initialize on the native alphanumeric page while preserving every
    // subsequent instruction exactly.
    const PATCH_OFFSET: usize = 0x1fa4;
    const ORIGINAL_WORD: u32 = 0x2402_0001;
    const PATCHED_WORD: u32 = 0x2402_0002;

    fn read_word(bytes: &[u8], offset: usize) -> anyhow::Result<u32> {
        Ok(u32::from_le_bytes(
            bytes
                .get(offset..offset + 4)
                .context("MGENT instruction read is truncated")?
                .try_into()?,
        ))
    }

    let input = Path::new(INPUT);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let report_path = Path::new(REPORT);

    ensure!(input.is_file(), "v6 input BIN is missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v6 input SHA changed"
    );

    fs::create_dir_all(
        output_bin
            .parent()
            .context("v7 output BIN has no parent directory")?,
    )?;

    let (_, source) = crate::disc::rebuild::read_record(input, MGENT_PATH)?;
    ensure!(source.len() == MGENT_SIZE, "MGENT.BIN size changed");
    ensure!(
        crate::pipeline::sha256_bytes(&source) == MGENT_V6_SHA256,
        "v6 MGENT.BIN source identity changed"
    );

    // Exact target and neighbors.
    ensure!(
        read_word(&source, 0x1fa0)? == 0xa202_0001,
        "nickname initializer preceding store changed"
    );
    ensure!(
        read_word(&source, PATCH_OFFSET)? == ORIGINAL_WORD,
        "nickname page immediate source changed at +0x1fa4"
    );
    ensure!(
        read_word(&source, 0x1fa8)? == 0xa202_0009,
        "nickname page-index store changed"
    );
    ensure!(
        read_word(&source, 0x1fac)? == 0x2402_0002,
        "nickname follow-up v0=2 load changed"
    );
    ensure!(
        read_word(&source, 0x1fb0)? == 0xa200_0002,
        "nickname neighboring initializer changed"
    );

    let mut patched = source.clone();
    patched[PATCH_OFFSET..PATCH_OFFSET + 4]
        .copy_from_slice(&PATCHED_WORD.to_le_bytes());

    ensure!(
        read_word(&patched, PATCH_OFFSET)? == PATCHED_WORD,
        "nickname page immediate readback mismatch"
    );

    let changed = source
        .iter()
        .zip(&patched)
        .enumerate()
        .filter_map(|(i, (a, b))| (a != b).then_some(i))
        .collect::<Vec<_>>();

    ensure!(
        changed.iter().all(|i| (PATCH_OFFSET..PATCH_OFFSET + 4).contains(i)),
        "MGENT changed outside the nickname page-immediate word"
    );
    ensure!(!changed.is_empty(), "nickname A-Z patch changed no bytes");

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: MGENT_PATH,
        data: &patched,
    }];

    let rebuilt =
        crate::disc::rebuild::copy_and_replace_records(input, output_bin, &replacements)?;
    ensure!(rebuilt.len() == 1, "disc rebuild replaced more than MGENT.BIN");

    let (_, readback) = crate::disc::rebuild::read_record(output_bin, MGENT_PATH)?;
    ensure!(readback == patched, "MGENT.BIN disc readback differs");
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v7 changed no disc sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v7 changed sectors outside MGENT.BIN"
    );

    let bin_name = output_bin
        .file_name()
        .context("v7 output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 English nickname default A-Z v7",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "mgent_source_sha256": MGENT_V6_SHA256,
        "mgent_patched_sha256": crate::pipeline::sha256_bytes(&patched),
        "patch_offset": "0x1fa4",
        "original_word": format!("0x{ORIGINAL_WORD:08x}"),
        "patched_word": format!("0x{PATCHED_WORD:08x}"),
        "changed_mgent_byte_count": changed.len(),
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "nickname_default_page_index": 2,
        "nickname_default_page_role": "alphanumeric",
        "ma_ent_biz_untouched": true,
        "readback_verified": true,
        "disc_length_preserved": true,
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("NICKNAME_DEFAULT_AZ_V7_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("MGENT_PATCHED_SHA256={}", crate::pipeline::sha256_bytes(&patched));
    eprintln!("CHANGED_MGENT_BYTES={}", changed.len());
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
    Write-Host "[1/2] Building nickname-default-A-Z MGENT patch..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_nickname_default_az_v7",
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

if (-not (Test-Path $OutputBin)) { Fail "v7 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v7 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v7 report JSON missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NICKNAME DEFAULT A-Z v7 COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Patched MGENT bytes: {0}" -f $Report.changed_mgent_byte_count)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "Expected live behavior:" -ForegroundColor Cyan
Write-Host "  NAME opens directly on A-Z."
Write-Host "  Moving to NICKNAME also opens/retains A-Z."
Write-Host "  HIRA/KATA/A-Z cycling still works."
Write-Host "  v5 graphics remain unchanged."
Write-Host ""
Write-Host "Do NOT promote v7 until live-tested." -ForegroundColor Yellow

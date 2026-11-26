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

$MasterBin = Join-Path $Upstream "work\english-name-entry-ui-v5\build\justice-gakuen2-name-entry-ui-v5.bin"
$ExpectedMasterHash = "2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977"

$WorkRoot = Join-Path $Upstream "work\english-name-entry-default-az-v6"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-name-entry-default-az-v6.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-name-entry-default-az-v6.cue"
$ReportJson = Join-Path $BuildDir "name-entry-default-az-v6-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY DEFAULT A-Z v6" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing upstream\src\dialogue_audit\name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing proven v5 English master BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v5 master hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_NAME_ENTRY_DEFAULT_AZ_V6"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale v6 injection already exists in name_entry_input_tests.rs."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_NAME_ENTRY_DEFAULT_AZ_V6
#[test]
fn english_project_name_entry_default_az_v6() -> anyhow::Result<()> {
    use anyhow::{Context, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    const INPUT: &str = "$MasterLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";

    const INPUT_SHA256: &str =
        "2fe51561d025cc2ffdface62d1a7e7222a40937bb3b5a97ebc019f8338d43977";
    const MGENT_PATH: &str = "DAT1/MGENT.BIN";
    const MGENT_SHA256: &str =
        "eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a";
    const MGENT_SIZE: usize = 36_796;

    // Cold-start initializer around +0x1a54.
    //
    // Original:
    //   1a54: addiu v0, zero, 0x0200
    //   1a58: sb    zero, 2(s0)
    //   1a5c: sb    zero, 9(s0)       ; page = HIRA (0)
    //   1a60: sb    zero, 10(s0)
    //   1a64: sb    zero, 13(s0)
    //   1a68: sb    zero, 12(s0)
    //   1a6c: sb    zero, 15(s0)
    //   1a70: sb    zero, 16(s0)
    //   1a74: sh    v0, 0x84(s0)
    //
    // Patched:
    //   1a54: addiu v0, zero, 2
    //   1a5c: sb    v0, 9(s0)         ; page = A-Z (2)
    //   1a64: sh    zero, 12(s0)      ; preserves zeroing of bytes 12 + 13
    //   1a68: addiu v0, zero, 0x0200  ; restores original v0 before 1a74
    //
    // All other object-field initialization remains byte-for-byte original.
    const PATCHES: &[(usize, u32, u32, &str)] = &[
        (
            0x1a54,
            0x2402_0200,
            0x2402_0002,
            "load A-Z page index 2",
        ),
        (
            0x1a5c,
            0xa200_0009,
            0xa202_0009,
            "store page index 2 at object +9",
        ),
        (
            0x1a64,
            0xa200_000d,
            0xa600_000c,
            "zero object bytes +12 and +13 together",
        ),
        (
            0x1a68,
            0xa200_000c,
            0x2402_0200,
            "restore v0 to original 0x0200",
        ),
    ];

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

    ensure!(input.is_file(), "v5 English master BIN is missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v5 English master SHA changed"
    );

    fs::create_dir_all(
        output_bin
            .parent()
            .context("v6 output BIN has no parent directory")?,
    )?;

    let (_, source) = crate::disc::rebuild::read_record(input, MGENT_PATH)?;
    ensure!(source.len() == MGENT_SIZE, "MGENT.BIN size changed");
    ensure!(
        crate::pipeline::sha256_bytes(&source) == MGENT_SHA256,
        "MGENT.BIN source identity changed"
    );

    // Verify exact source instructions before touching anything.
    for &(offset, expected, _, label) in PATCHES {
        let actual = read_word(&source, offset)?;
        ensure!(
            actual == expected,
            "{label}: source word changed at +0x{offset:04x}: expected 0x{expected:08x}, found 0x{actual:08x}"
        );
    }

    // Verify the untouched neighboring initializer instructions that make this
    // four-instruction transformation semantics-preserving.
    let neighbor_guards: &[(usize, u32, &str)] = &[
        (0x1a58, 0xa200_0002, "zero object +2"),
        (0x1a60, 0xa200_000a, "zero object +10"),
        (0x1a6c, 0xa200_000f, "zero object +15"),
        (0x1a70, 0xa200_0010, "zero object +16"),
        (0x1a74, 0xa602_0084, "store original 0x0200 halfword at +0x84"),
        (0x1a78, 0x1060_0006, "branch using preserved v1"),
        (0x1a7c, 0xa600_0086, "zero halfword +0x86"),
    ];
    for &(offset, expected, label) in neighbor_guards {
        ensure!(
            read_word(&source, offset)? == expected,
            "{label}: neighboring initializer word changed at +0x{offset:04x}"
        );
    }

    let mut patched = source.clone();
    let mut patch_report = Vec::new();

    for &(offset, expected, replacement, label) in PATCHES {
        ensure!(read_word(&patched, offset)? == expected, "pre-write drift");
        patched[offset..offset + 4].copy_from_slice(&replacement.to_le_bytes());
        ensure!(
            read_word(&patched, offset)? == replacement,
            "{label}: readback mismatch at +0x{offset:04x}"
        );
        patch_report.push(json!({
            "offset": format!("0x{offset:04x}"),
            "original_word": format!("0x{expected:08x}"),
            "patched_word": format!("0x{replacement:08x}"),
            "purpose": label,
        }));
    }

    // Prove that only the four intended 32-bit words changed inside MGENT.
    let changed_offsets = source
        .iter()
        .zip(&patched)
        .enumerate()
        .filter_map(|(i, (a, b))| (a != b).then_some(i))
        .collect::<Vec<_>>();

    let expected_changed_byte_set = PATCHES
        .iter()
        .flat_map(|(offset, _, _, _)| *offset..*offset + 4)
        .filter(|&i| source[i] != patched[i])
        .collect::<std::collections::BTreeSet<_>>();
    let actual_changed_byte_set = changed_offsets
        .iter()
        .copied()
        .collect::<std::collections::BTreeSet<_>>();

    ensure!(
        actual_changed_byte_set == expected_changed_byte_set,
        "MGENT changed bytes outside the four intended instruction words"
    );

    // Semantic postconditions for the initializer rewrite.
    ensure!(read_word(&patched, 0x1a54)? == 0x2402_0002, "v0 is not loaded with page 2");
    ensure!(read_word(&patched, 0x1a5c)? == 0xa202_0009, "page 2 is not stored at +9");
    ensure!(read_word(&patched, 0x1a64)? == 0xa600_000c, "bytes +12/+13 are not jointly zeroed");
    ensure!(read_word(&patched, 0x1a68)? == 0x2402_0200, "v0 is not restored to 0x0200");
    ensure!(read_word(&patched, 0x1a74)? == 0xa602_0084, "original later halfword store changed");

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
        crate::pipeline::sha256_bytes(&readback) == crate::pipeline::sha256_bytes(&patched),
        "MGENT.BIN readback SHA differs"
    );
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v6 changed no disc sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v6 changed sectors outside MGENT.BIN"
    );

    let bin_name = output_bin
        .file_name()
        .context("v6 output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 English name-entry default A-Z v6",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "mgent_source_sha256": MGENT_SHA256,
        "mgent_patched_sha256": crate::pipeline::sha256_bytes(&patched),
        "mgent_size": patched.len(),
        "patched_instruction_count": PATCHES.len(),
        "changed_mgent_byte_count": actual_changed_byte_set.len(),
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "patches": patch_report,
        "default_page_index": 2,
        "default_page_role": "alphanumeric",
        "ma_ent_biz_untouched": true,
        "readback_verified": true,
        "disc_length_preserved": true,
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("NAME_ENTRY_DEFAULT_AZ_V6_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("MGENT_PATCHED_SHA256={}", crate::pipeline::sha256_bytes(&patched));
    eprintln!("CHANGED_MGENT_BYTES={}", actual_changed_byte_set.len());
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
    Write-Host "[1/2] Building default-A-Z MGENT behavior patch..." -ForegroundColor Cyan
    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_name_entry_default_az_v6",
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

if (-not (Test-Path $OutputBin)) { Fail "v6 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v6 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v6 report JSON missing." }

Write-Host ""
Write-Host "[2/2] Verifying final output..." -ForegroundColor Cyan

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()

if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "NAME ENTRY DEFAULT A-Z v6 COMPLETE" -ForegroundColor Green
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
Write-Host "  HIRA/KATA/A-Z cycling still works."
Write-Host "  Form graphics and v5 English control labels are unchanged."
Write-Host ""
Write-Host "Do NOT promote this over v5 until the live screen is tested." -ForegroundColor Yellow

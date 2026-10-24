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

$WorkRoot = Join-Path $Upstream "work\english-name-entry-page-seed-probe-v1"
$ReportPath = Join-Path $WorkRoot "name-entry-page-seed-probe-v1.txt"

Write-Host ""
Write-Host "Justice Gakuen English Project - NAME ENTRY PAGE SEED PROBE v1" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Upstream)) { Fail "Missing upstream folder beside this script." }
if (-not (Test-Path $RustPath)) { Fail "Missing name_entry_input_tests.rs." }
if (-not (Test-Path $MasterBin)) { Fail "Missing v5 English master BIN." }

$MasterHash = (Get-FileHash $MasterBin -Algorithm SHA256).Hash.ToLower()
Write-Host ("Master BIN SHA-256: {0}" -f $MasterHash)
if ($MasterHash -ne $ExpectedMasterHash) {
    Fail "v5 master hash mismatch. Nothing was changed."
}
Write-Host "Master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null

$OriginalRust = [System.IO.File]::ReadAllText($RustPath)
$Marker = "// ENGLISH_PROJECT_PAGE_SEED_PROBE_V1"
if ($OriginalRust.Contains($Marker)) {
    Fail "Stale page-seed probe injection already exists."
}

$MasterLiteral = $MasterBin.Replace("\", "\\")
$ReportLiteral = $ReportPath.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_PAGE_SEED_PROBE_V1
#[test]
fn english_project_page_seed_probe_v1() -> anyhow::Result<()> {
    use psx_r3000a::{decode, Instruction, Register};
    use std::fmt::Write as _;
    use std::path::Path;

    const INPUT: &str = "$MasterLiteral";
    const REPORT: &str = "$ReportLiteral";
    const OVERLAY_RUNTIME_BASE: u32 = 0x80179000;

    let input = Path::new(INPUT);
    let (_, overlay) = crate::disc::rebuild::read_record(input, "DAT1/MGENT.BIN")?;
    anyhow::ensure!(
        crate::pipeline::sha256_bytes(&overlay)
            == "eaf243e2d5a78919055b453611ea08b785766a6dc945966a1d5c0ce166714f70a"
            || crate::pipeline::sha256_bytes(&overlay)
            == "eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a",
        "MGENT.BIN source identity changed"
    );

    let mut report = String::new();
    writeln!(&mut report, "Justice Gakuen 2 name-entry page seed probe")?;
    writeln!(&mut report, "MGENT size: {}", overlay.len())?;
    writeln!(
        &mut report,
        "MGENT SHA-256: {}",
        crate::pipeline::sha256_bytes(&overlay)
    )?;
    writeln!(&mut report)?;

    let mut stores = Vec::new();
    for offset in (0..overlay.len().saturating_sub(3)).step_by(4) {
        let word = u32::from_le_bytes(overlay[offset..offset + 4].try_into()?);
        let pc = OVERLAY_RUNTIME_BASE + offset as u32;
        let Ok(inst) = decode(word, pc) else {
            continue;
        };
        if matches!(
            inst,
            Instruction::Sb {
                base: Register::S0,
                offset: 9,
                ..
            }
        ) {
            stores.push((offset, inst));
        }
    }

    writeln!(&mut report, "SB ?, 9(S0) stores: {}", stores.len())?;
    writeln!(&mut report)?;

    for (offset, inst) in stores {
        writeln!(
            &mut report,
            "=== candidate file +0x{offset:04x} / runtime 0x{:08x} ===",
            OVERLAY_RUNTIME_BASE + offset as u32
        )?;
        writeln!(&mut report, "TARGET: {inst:?}")?;

        let start = offset.saturating_sub(0x30) & !3usize;
        let end = (offset + 0x34).min(overlay.len()) & !3usize;
        for at in (start..end).step_by(4) {
            let word = u32::from_le_bytes(overlay[at..at + 4].try_into()?);
            let pc = OVERLAY_RUNTIME_BASE + at as u32;
            let decoded = decode(word, pc)
                .map(|i| format!("{i:?}"))
                .unwrap_or_else(|_| format!("<decode failed 0x{word:08x}>"));
            let mark = if at == offset { ">>" } else { "  " };
            writeln!(
                &mut report,
                "{mark} +0x{at:04x}  0x{pc:08x}  {word:08x}  {decoded}"
            )?;
        }
        writeln!(&mut report)?;
    }

    std::fs::write(REPORT, report)?;
    eprintln!("PAGE_SEED_PROBE_COMPLETE=1");
    eprintln!("REPORT={REPORT}");
    Ok(())
}

"@

try {
    [System.IO.File]::WriteAllText(
        $RustPath,
        $OriginalRust.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_page_seed_probe_v1",
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

if (-not (Test-Path $ReportPath)) {
    Fail "Probe report was not created."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "PAGE SEED PROBE COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "REPORT:" -ForegroundColor Yellow
Write-Host $ReportPath
Write-Host ""
Write-Host "Nothing was modified." -ForegroundColor Green
Write-Host "Paste or upload the TXT report." -ForegroundColor Green

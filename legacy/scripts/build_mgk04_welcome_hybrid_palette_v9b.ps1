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

function Read-Utf8Text([string]$Path) {
    return [System.IO.File]::ReadAllText(
        $Path,
        [System.Text.UTF8Encoding]::new($false, $true)
    )
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"

$V8Bin = Join-Path $Upstream "work\english-name-entry-school-choices-v8\build\justice-gakuen2-name-entry-school-choices-v8.bin"
$ExpectedV8Hash = "07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84"

$TutorialV3Script = Join-Path $Here "build_mgk04_full_tutorial_v3.ps1"
$MessagePlanRs = Join-Path $Upstream "src\dialogue_audit\dialogue_message_plan.rs"
$TestRs = Join-Path $Upstream "src\dialogue_audit\name_entry_input_tests.rs"

$HybridTutorialBin = Join-Path $Upstream "work\english-mgk04-full-tutorial-v3\build\justice-gakuen2-mgk04-full-tutorial-v3.bin"

$WorkRoot = Join-Path $Upstream "work\english-mgk04-welcome-hybrid-v9b"
$BuildDir = Join-Path $WorkRoot "build"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-mgk04-welcome-hybrid-v9b.bin"
$OutputCue = Join-Path $BuildDir "justice-gakuen2-mgk04-welcome-hybrid-v9b.cue"
$ReportJson = Join-Path $BuildDir "mgk04-welcome-hybrid-v9b-report.json"

Write-Host ""
Write-Host "Justice Gakuen English Project - MGK04 WELCOME HYBRID PALETTE v9b" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $V8Bin)) { Fail "Missing live-tested v8 master BIN." }
if (-not (Test-Path $TutorialV3Script)) { Fail "Missing build_mgk04_full_tutorial_v3.ps1 in project root." }
if (-not (Test-Path $MessagePlanRs)) { Fail "Missing upstream dialogue_message_plan.rs." }
if (-not (Test-Path $TestRs)) { Fail "Missing upstream name_entry_input_tests.rs." }

$V8Hash = (Get-FileHash $V8Bin -Algorithm SHA256).Hash.ToLower()
Write-Host ("v8 master BIN SHA-256: {0}" -f $V8Hash)
if ($V8Hash -ne $ExpectedV8Hash) {
    Fail "v8 master hash mismatch. Nothing was changed."
}
Write-Host "v8 master verified." -ForegroundColor Green

if (Test-Path $WorkRoot) {
    Remove-Item $WorkRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# ---------------------------------------------------------------------------
# Temporarily correct the old MGK04 greeting planner bug.
#
# Existing runtime rewrite:
#   palette(title)
#   line_break              <- source body palette was converted to this
#   line_break
#   end
#
# Correct hybrid:
#   palette(title = 0x0009 blue)
#   line_break              <- cloned native line-break control
#   palette(body = 0x00ff white)
#   line_break
#   end
#
# This adds two 16-bit words relative to the current source-size-neutral
# reflow: one line-break control plus the restored palette argument. It also
# adds one empty logical segment so the encoder shape invariant remains valid.
# The full tutorial builder must prove the message arena can hold it.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[1/3] Preparing hybrid title/body palette planner..." -ForegroundColor Cyan

$OriginalPlan = Read-Utf8Text $MessagePlanRs
$WelcomeMarker = "ENGLISH_PROJECT_MGK04_WELCOME_CONTROL_V2"
$BlueMarker = "ENGLISH_PROJECT_MGK04_BLUE_TITLE_V1"

if (-not $OriginalPlan.Contains($WelcomeMarker)) {
    Fail "Current upstream source lacks the proven MGK04 welcome-control marker."
}
if (-not $OriginalPlan.Contains($BlueMarker)) {
    Fail "Current upstream source lacks the proven blue-title marker."
}
if (-not $OriginalPlan.Contains('controls[0].arguments.push("0x0009".to_string());')) {
    Fail "Current planner no longer sets the title palette to native blue 0x0009."
}

$OldMutation = @'
        controls[1].semantic_name = "line_break".to_string();
        controls[1].arguments.clear();
'@

$OldCount = ([regex]::Matches(
    $OriginalPlan,
    [regex]::Escape($OldMutation.Trim())
)).Count

if ($OldCount -ne 1) {
    Fail ("Expected exactly one old body-palette-to-line-break mutation; found {0}." -f $OldCount)
}

$HybridMutation = @'
        // ENGLISH_PROJECT_MGK04_WELCOME_HYBRID_V9B:
        // Preserve the source body palette as normal dialogue white and add a
        // separate line break between the blue title and the body.
        //
        // Adding one control also requires one extra text segment because the
        // encoder requires segments.len() == controls.len() + 1. The inserted
        // empty segment carries no glyphs; it simply occupies the legal slot
        // between the title line break and the white-palette control.
        let title_line_break = controls[2].clone();
        ensure!(
            title_line_break.semantic_name == "line_break"
                && title_line_break.arguments.is_empty(),
            "MGK04 welcome native line-break control changed"
        );
        controls[1].arguments.clear();
        controls[1].arguments.push("0x00ff".to_string());
        controls.insert(1, title_line_break);

        let segments = translated_segments
            .get_mut(ENGLISH_MGK04_WELCOME_HASH)
            .expect("MGK04 welcome translated segments disappeared");
        ensure!(
            segments.len() == 5
                && segments[0].is_empty()
                && segments[1] == "SCHOOL LIFE 2"
                && segments[2] == "WELCOME!"
                && segments[3] == "HAVE A GREAT YEAR!"
                && segments[4].is_empty(),
            "MGK04 welcome translated segment shape changed before hybrid insertion"
        );
        segments.insert(2, String::new());
'@

$PatchedPlan = $OriginalPlan.Replace($OldMutation.Trim(), $HybridMutation.Trim())

if ($PatchedPlan -eq $OriginalPlan) {
    Fail "Hybrid planner replacement did not modify dialogue_message_plan.rs."
}
if (-not $PatchedPlan.Contains("ENGLISH_PROJECT_MGK04_WELCOME_HYBRID_V9B")) {
    Fail "Hybrid planner marker was not installed."
}
if (-not $PatchedPlan.Contains('controls[1].arguments.push("0x00ff".to_string());')) {
    Fail "Hybrid planner is missing the body white palette."
}
if (-not $PatchedPlan.Contains("controls.insert(1, title_line_break);")) {
    Fail "Hybrid planner is missing the inserted title line break."
}
if (-not $PatchedPlan.Contains("segments.insert(2, String::new());")) {
    Fail "Hybrid planner is missing the empty segment required by the encoder shape invariant."
}

# Run the known-good full tutorial builder with only this temporary planner
# change. Always restore dialogue_message_plan.rs afterward.
try {
    Write-Utf8NoBom $MessagePlanRs $PatchedPlan

    Write-Host ""
    Write-Host "[2/3] Rebuilding full MGK04 tutorial with blue title + white body..." -ForegroundColor Cyan
    Write-Host "      This is the capacity test too: if the arena cannot hold the extra controls, the build stops here." -ForegroundColor DarkGray
    Write-Host ""

    & powershell -ExecutionPolicy Bypass -File $TutorialV3Script
    if ($LASTEXITCODE -ne 0) {
        Fail "Full MGK04 tutorial rebuild failed. The planner source will be restored automatically."
    }
}
finally {
    Write-Utf8NoBom $MessagePlanRs $OriginalPlan
}

$RestoredPlan = Read-Utf8Text $MessagePlanRs
if ($RestoredPlan -ne $OriginalPlan) {
    Fail "dialogue_message_plan.rs did not restore byte-for-byte after the temporary hybrid build."
}
Write-Host "Planner source restored byte-for-byte." -ForegroundColor Green

if (-not (Test-Path $HybridTutorialBin)) {
    Fail "Hybrid tutorial build did not produce its expected BIN."
}

# ---------------------------------------------------------------------------
# Transplant ONLY the newly rebuilt MGK04.BIZ record onto the live-tested v8
# master, preserving all name-entry behavior + graphics + school choices.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/3] Transplanting only DAT2/MGK04.BIZ onto v8 and verifying readback..." -ForegroundColor Cyan

$OriginalTest = [System.IO.File]::ReadAllText($TestRs)
$Marker = "// ENGLISH_PROJECT_MGK04_WELCOME_HYBRID_TRANSPLANT_V9B"
if ($OriginalTest.Contains($Marker)) {
    Fail "Stale v9 transplant injection already exists in name_entry_input_tests.rs."
}

$V8Literal = $V8Bin.Replace("\", "\\")
$HybridLiteral = $HybridTutorialBin.Replace("\", "\\")
$OutputBinLiteral = $OutputBin.Replace("\", "\\")
$OutputCueLiteral = $OutputCue.Replace("\", "\\")
$ReportLiteral = $ReportJson.Replace("\", "\\")

$Rust = @"

// ENGLISH_PROJECT_MGK04_WELCOME_HYBRID_TRANSPLANT_V9B
#[test]
fn english_project_mgk04_welcome_hybrid_transplant_v9b() -> anyhow::Result<()> {
    use anyhow::{Context, ensure};
    use serde_json::json;
    use std::fs;
    use std::path::Path;

    const INPUT: &str = "$V8Literal";
    const HYBRID_SOURCE: &str = "$HybridLiteral";
    const OUTPUT_BIN: &str = "$OutputBinLiteral";
    const OUTPUT_CUE: &str = "$OutputCueLiteral";
    const REPORT: &str = "$ReportLiteral";

    const INPUT_SHA256: &str =
        "07b4dda156ab0eac7f149f66f7bcb9727a8e74fad4faa2d19d77cee362504d84";
    const TARGET_PATH: &str = "DAT2/MGK04.BIZ";

    let input = Path::new(INPUT);
    let hybrid_source = Path::new(HYBRID_SOURCE);
    let output_bin = Path::new(OUTPUT_BIN);
    let output_cue = Path::new(OUTPUT_CUE);
    let report_path = Path::new(REPORT);

    ensure!(input.is_file(), "v8 master BIN is missing");
    ensure!(hybrid_source.is_file(), "hybrid tutorial source BIN is missing");
    ensure!(
        crate::pipeline::sha256_file(input)? == INPUT_SHA256,
        "v8 master SHA changed"
    );

    fs::create_dir_all(
        output_bin
            .parent()
            .context("v9 output BIN has no parent directory")?,
    )?;

    let (_, old_record) = crate::disc::rebuild::read_record(input, TARGET_PATH)?;
    let (_, hybrid_record) =
        crate::disc::rebuild::read_record(hybrid_source, TARGET_PATH)?;

    ensure!(
        old_record.len() == hybrid_record.len(),
        "hybrid MGK04 fixed-record size changed"
    );
    ensure!(
        old_record != hybrid_record,
        "hybrid MGK04 record is byte-identical to v8; palette reflow did not land"
    );

    let old_decoded = crate::compression::decompress(&old_record, true)?;
    let hybrid_decoded = crate::compression::decompress(&hybrid_record, true)?;
    ensure!(
        old_decoded.len() == hybrid_decoded.len(),
        "hybrid MGK04 decoded size changed"
    );

    let changed_decoded_bytes = old_decoded
        .iter()
        .zip(&hybrid_decoded)
        .filter(|(a, b)| a != b)
        .count();
    ensure!(
        changed_decoded_bytes > 0,
        "hybrid MGK04 decoded data did not change"
    );

    let replacements = [crate::disc::rebuild::FixedRecordReplacement {
        path: TARGET_PATH,
        data: &hybrid_record,
    }];

    let rebuilt =
        crate::disc::rebuild::copy_and_replace_records(input, output_bin, &replacements)?;
    ensure!(rebuilt.len() == 1, "v9 replaced more than MGK04.BIZ");

    let (_, readback) = crate::disc::rebuild::read_record(output_bin, TARGET_PATH)?;
    ensure!(readback == hybrid_record, "MGK04.BIZ disc readback differs");
    ensure!(
        crate::compression::decompress(&readback, true)? == hybrid_decoded,
        "MGK04.BIZ decoded disc readback differs"
    );
    ensure!(
        fs::metadata(input)?.len() == fs::metadata(output_bin)?.len(),
        "disc image length changed"
    );

    let (changed_lbas, output_sha256) =
        crate::disc::rebuild::compare_and_hash_images(input, output_bin)?;
    ensure!(!changed_lbas.is_empty(), "v9 changed no disc sectors");
    ensure!(
        changed_lbas.iter().all(|lba| {
            rebuilt.iter().any(|record| record.target_lbas.contains(lba))
        }),
        "v9 changed sectors outside MGK04.BIZ"
    );

    let bin_name = output_bin
        .file_name()
        .context("v9 output BIN has no filename")?
        .to_string_lossy();
    fs::write(
        output_cue,
        format!(
            "FILE \"{bin_name}\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n"
        ),
    )?;

    let report = json!({
        "kind": "Justice Gakuen 2 MGK04 welcome hybrid palette v9b",
        "input_bin_sha256": INPUT_SHA256,
        "output_bin_sha256": output_sha256,
        "target_path": TARGET_PATH,
        "v8_mgk04_stored_sha256": crate::pipeline::sha256_bytes(&old_record),
        "hybrid_mgk04_stored_sha256": crate::pipeline::sha256_bytes(&hybrid_record),
        "v8_mgk04_decoded_sha256": crate::pipeline::sha256_bytes(&old_decoded),
        "hybrid_mgk04_decoded_sha256": crate::pipeline::sha256_bytes(&hybrid_decoded),
        "changed_decoded_byte_count": changed_decoded_bytes,
        "changed_sector_count": changed_lbas.len(),
        "changed_lbas": changed_lbas,
        "title_palette": "0x0009 native blue",
        "body_palette": "0x00ff normal white",
        "mgk04_only": true,
        "readback_verified": true,
        "disc_length_preserved": true,
        "cue": output_cue.display().to_string(),
    });

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    fs::write(report_path, report_bytes)?;

    eprintln!("MGK04_WELCOME_HYBRID_V9B_COMPLETE=1");
    eprintln!("OUTPUT_SHA256={output_sha256}");
    eprintln!("OLD_MGK04_STORED_SHA256={}", crate::pipeline::sha256_bytes(&old_record));
    eprintln!("HYBRID_MGK04_STORED_SHA256={}", crate::pipeline::sha256_bytes(&hybrid_record));
    eprintln!("CHANGED_DECODED_BYTES={changed_decoded_bytes}");
    eprintln!("CHANGED_RAW_SECTORS={}", changed_lbas.len());
    eprintln!("CUE={}", output_cue.display());

    Ok(())
}

"@

try {
    [System.IO.File]::WriteAllText(
        $TestRs,
        $OriginalTest.TrimEnd() + [Environment]::NewLine + $Rust + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    Push-Location $Upstream
    try {
        Run-Native "cargo" @(
            "test", "--lib",
            "english_project_mgk04_welcome_hybrid_transplant_v9b",
            "--", "--nocapture"
        )
    }
    finally {
        Pop-Location
    }
}
finally {
    [System.IO.File]::WriteAllText(
        $TestRs,
        $OriginalTest,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path $OutputBin)) { Fail "v9 output BIN missing." }
if (-not (Test-Path $OutputCue)) { Fail "v9 output CUE missing." }
if (-not (Test-Path $ReportJson)) { Fail "v9 report JSON missing." }

$Report = Get-Content $ReportJson -Raw -Encoding UTF8 | ConvertFrom-Json
$OutputHash = (Get-FileHash $OutputBin -Algorithm SHA256).Hash.ToLower()
if ($OutputHash -ne ([string]$Report.output_bin_sha256).ToLower()) {
    Fail "PowerShell output SHA does not match the Rust report."
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "MGK04 WELCOME HYBRID PALETTE v9b COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("Output BIN SHA-256: {0}" -f $OutputHash)
Write-Host ("Changed decoded MGK04 bytes: {0}" -f $Report.changed_decoded_byte_count)
Write-Host ("Changed raw sectors: {0}" -f $Report.changed_sector_count)
Write-Host ""
Write-Host "CUE TO TEST:" -ForegroundColor Yellow
Write-Host $OutputCue
Write-Host ""
Write-Host "Expected first greeting:" -ForegroundColor Cyan
Write-Host "  SCHOOL LIFE 2        = native blue/lavender"
Write-Host "  WELCOME!             = normal white"
Write-Host "  HAVE A GREAT YEAR!   = normal white"
Write-Host ""
Write-Host "Only DAT2/MGK04.BIZ is transplanted onto v8." -ForegroundColor Green
Write-Host "Do NOT promote v9 until the first greeting and next dialogue screen are live-tested." -ForegroundColor Yellow

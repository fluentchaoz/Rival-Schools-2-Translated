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

if (-not (Test-Path $Upstream)) {
    Fail "Missing upstream folder. Run continue_phase1_fixed.ps1 first."
}

$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"

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
    $ProbeMarker = "fn english_gate1_nochange_rebuild_is_byte_identical()"

    $sourceText = [System.IO.File]::ReadAllText($ProbePath)
    if (-not $sourceText.Contains($ProbeMarker)) {
        $Probe = @'

#[cfg(test)]
mod english_gate1_nochange_rebuild {
    use super::*;
    use std::path::Path;

    #[test]
    fn english_gate1_nochange_rebuild_is_byte_identical() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let source = SupportedSourceDisc::open(
            &root.join("roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"),
        )
        .expect("adapted source profile must accept the audited BIN");

        let (_, main_exe) = source.read_record("SLPS_021.20").unwrap();

        let work = root.join("work");
        std::fs::create_dir_all(&work).unwrap();
        let output = work.join("gate1-nochange.bin");
        if output.exists() {
            std::fs::remove_file(&output).unwrap();
        }

        let rebuilt = crate::disc::rebuild::copy_and_replace_record(
            source.image_path(),
            &output,
            "SLPS_021.20",
            &main_exe,
        )
        .expect("no-change rebuild must succeed");

        assert!(
            rebuilt.changed_lbas.is_empty(),
            "identical record replacement unexpectedly changed payload sectors: {:?}",
            rebuilt.changed_lbas
        );

        let (changed_lbas, output_sha256) =
            crate::disc::rebuild::compare_and_hash_images(source.image_path(), &output)
                .expect("rebuilt image comparison must succeed");

        assert!(
            changed_lbas.is_empty(),
            "no-change rebuilt image differs at LBAs: {:?}",
            changed_lbas
        );
        assert_eq!(
            output_sha256,
            "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
        );

        let source_size = std::fs::metadata(source.image_path()).unwrap().len();
        let output_size = std::fs::metadata(&output).unwrap().len();
        assert_eq!(output_size, source_size);

        let (_, rebuilt_exe) = crate::disc::rebuild::read_record(&output, "SLPS_021.20").unwrap();
        assert_eq!(rebuilt_exe, main_exe);
    }
}
'@
        [System.IO.File]::AppendAllText(
            $ProbePath,
            $Probe,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    Write-Host "Justice Gakuen English Project - Gate 1 no-change rebuild" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1/3] Running Rust no-change rebuild probe..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_gate1_nochange_rebuild::english_gate1_nochange_rebuild_is_byte_identical",
        "--", "--exact"
    )

    $BuiltBin = Join-Path $Upstream "work/gate1-nochange.bin"
    if (-not (Test-Path $BuiltBin)) {
        Fail "Rust test passed but rebuilt BIN was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Verifying output hash independently in PowerShell..."
    $outHash = (Get-FileHash -Algorithm SHA256 $BuiltBin).Hash.ToLower()
    Write-Host "Rebuilt BIN SHA-256: $outHash"
    if ($outHash -ne $ExpectedBinHash) {
        Fail "Rebuilt BIN is not byte-identical to the audited source."
    }

    Write-Host ""
    Write-Host "[3/3] Writing a matching CUE..."
    $BuiltCue = Join-Path $Upstream "work/gate1-nochange.cue"
    @'
FILE "gate1-nochange.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $BuiltCue

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "GATE 1 NO-CHANGE REBUILD PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Rebuilt BIN: $BuiltBin"
    Write-Host "Rebuilt CUE: $BuiltCue"
    Write-Host ""
    Write-Host "The rebuild pipeline produced a byte-for-byte identical disc image."
}
finally {
    Pop-Location
}

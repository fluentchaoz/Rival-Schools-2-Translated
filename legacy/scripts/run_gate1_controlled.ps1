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
    Fail "Missing upstream folder. Run the Phase 1 scripts first."
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
    $ProbeMarker = "fn english_gate1_controlled_change_is_confined_and_valid()"

    $sourceText = [System.IO.File]::ReadAllText($ProbePath)
    if (-not $sourceText.Contains($ProbeMarker)) {
        $Probe = @'

#[cfg(test)]
mod english_gate1_controlled_change {
    use super::*;
    use std::io::{Read, Seek, SeekFrom};
    use std::path::Path;

    #[test]
    fn english_gate1_controlled_change_is_confined_and_valid() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let source = SupportedSourceDisc::open(
            &root.join("roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"),
        )
        .expect("adapted source profile must accept the audited BIN");

        let (_, stored) = source.read_record("DAT1/MGTIT.BIZ").unwrap();
        let mut decoded = crate::compression::decompress(&stored, true).unwrap();

        assert_eq!(decoded.len(), 48_360);
        assert!(
            decoded[0xa400..0xbce8].iter().all(|byte| *byte == 0),
            "audited MGTIT scratch region is no longer zero-filled"
        );

        // Deliberately change one byte inside the audited unused patch-storage region.
        decoded[0xa400] = 0x52;

        let (encoded, _, _) =
            crate::title_menu::compress_title_overlay_with_source_limits(&decoded, &stored)
                .expect("MGTIT recompression with source limits must succeed");

        assert!(
            encoded.len() <= stored.len(),
            "controlled MGTIT stream grew beyond its fixed on-disc record"
        );

        let mut padded = encoded;
        padded.resize(stored.len(), 0);

        assert_eq!(
            crate::compression::decompress(&padded, true).unwrap(),
            decoded,
            "controlled MGTIT recompression did not round-trip"
        );

        let work = root.join("work");
        std::fs::create_dir_all(&work).unwrap();
        let output = work.join("gate1-controlled.bin");
        if output.exists() {
            std::fs::remove_file(&output).unwrap();
        }

        let rebuilt = crate::disc::rebuild::copy_and_replace_record(
            source.image_path(),
            &output,
            "DAT1/MGTIT.BIZ",
            &padded,
        )
        .expect("controlled MGTIT disc rebuild must succeed");

        assert!(
            !rebuilt.changed_lbas.is_empty(),
            "controlled change unexpectedly changed no raw sectors"
        );
        assert!(
            rebuilt
                .changed_lbas
                .iter()
                .all(|lba| rebuilt.target_lbas.contains(lba)),
            "disc writer changed a sector outside the MGTIT.BIZ extent"
        );

        let (observed_lbas, _) =
            crate::disc::rebuild::compare_and_hash_images(source.image_path(), &output)
                .expect("controlled output comparison must succeed");

        assert_eq!(
            observed_lbas, rebuilt.changed_lbas,
            "whole-disc diff disagrees with the rebuild plan"
        );

        let (_, rebuilt_stored) =
            crate::disc::rebuild::read_record(&output, "DAT1/MGTIT.BIZ").unwrap();
        assert_eq!(rebuilt_stored, padded);
        assert_eq!(
            crate::compression::decompress(&rebuilt_stored, true).unwrap(),
            decoded
        );

        // Every changed raw sector must still carry valid Mode-2 protection.
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
                "rebuilt raw sector {lba} failed Mode-2 EDC/ECC verification"
            );
        }

        println!("CONTROLLED_CHANGED_LBAS={:?}", observed_lbas);
        println!("CONTROLLED_RECORD_EXTENT={:?}", rebuilt.target_lbas);
    }
}
'@
        [System.IO.File]::AppendAllText(
            $ProbePath,
            $Probe,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    Write-Host "Justice Gakuen English Project - Gate 1 controlled-change rebuild" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[1/3] Rebuilding MGTIT.BIZ with one harmless audited scratch-byte change..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_gate1_controlled_change::english_gate1_controlled_change_is_confined_and_valid",
        "--", "--exact", "--nocapture"
    )

    $BuiltBin = Join-Path $Upstream "work/gate1-controlled.bin"
    if (-not (Test-Path $BuiltBin)) {
        Fail "Rust test passed but gate1-controlled.bin was not produced."
    }

    Write-Host ""
    Write-Host "[2/3] Hashing modified output..."
    $outHash = (Get-FileHash -Algorithm SHA256 $BuiltBin).Hash.ToLower()
    Write-Host "Modified BIN SHA-256: $outHash"
    if ($outHash -eq $ExpectedBinHash) {
        Fail "Controlled-change output is unexpectedly identical to the source."
    }

    Write-Host ""
    Write-Host "[3/3] Writing matching CUE..."
    $BuiltCue = Join-Path $Upstream "work/gate1-controlled.cue"
    @'
FILE "gate1-controlled.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $BuiltCue

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "GATE 1 CONTROLLED-CHANGE REBUILD PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Modified BIN: $BuiltBin"
    Write-Host "Modified CUE: $BuiltCue"
    Write-Host ""
    Write-Host "Next: boot gate1-controlled.cue in DuckStation and confirm the game reaches the title screen."
}
finally {
    Pop-Location
}

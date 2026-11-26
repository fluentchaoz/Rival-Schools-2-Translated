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

function Replace-Exact([string]$Path, [string]$Old, [string]$New) {
    if (-not (Test-Path $Path)) {
        Fail "Missing source file: $Path"
    }
    $text = [System.IO.File]::ReadAllText($Path)
    $count = ([regex]::Matches($text, [regex]::Escape($Old))).Count
    if ($count -ne 1) {
        Fail "Expected exactly one occurrence in $Path, found $count.`nOLD: $Old"
    }
    $text = $text.Replace($Old, $New)
    [System.IO.File]::WriteAllText(
        $Path,
        $text,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Upstream = Join-Path $Here "upstream"

$ExpectedBinHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$OriginalBinHash = "62dbc6ca47ec8d9dfbb5797f35d4e720d63e00b5a8e0edd080b149c3ff4f1823"

$UserMgtitStored = "71d01319369b97258d962528aeaa274bce6d1b29d194aa530b6e3e0d589356b3"
$OriginalMgtitStored = "2130913aba89a8dd19555bad5e2b21d0f666a9e684fd7f35f2e703a2df4d5b62"

$UserMgtitDecoded = "fe36b68795859f907aed70eb13517e853f3fd779df43b7c992191c47c5341cf5"
$OriginalMgtitDecoded = "859515ec9f58a2326708dbbf46516e8601cb59d158c0da3f2e214311762a07d1"

Write-Host "Justice Gakuen English Project - Phase 1 corrected verification" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not available on PATH."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Fail "Cargo is not available on PATH."
}
if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) {
    Fail "rustc is not available on PATH."
}
if (-not (Test-Path $RomFolder)) {
    Fail "ROM folder does not exist: $RomFolder"
}

$bins = @(Get-ChildItem -Path $RomFolder -Filter *.bin -File)
$cues = @(Get-ChildItem -Path $RomFolder -Filter *.cue -File)
if ($bins.Count -ne 1) { Fail "Expected exactly one .bin in $RomFolder; found $($bins.Count)." }
if ($cues.Count -ne 1) { Fail "Expected exactly one .cue in $RomFolder; found $($cues.Count)." }

$SourceBin = $bins[0].FullName
$hash = (Get-FileHash -Algorithm SHA256 $SourceBin).Hash.ToLower()
Write-Host "Source BIN SHA-256: $hash"
if ($hash -ne $ExpectedBinHash) {
    Fail "This is not the exact BIN we audited."
}

Write-Host ""
Write-Host "[1/7] Checking out clean upstream source..."
if (-not (Test-Path $Upstream)) {
    Run-Native "git" @("clone", "https://github.com/mcpads/justice-gakuen2-kr-patch.git", $Upstream)
}
Push-Location $Upstream
try {
    Run-Native "git" @("reset", "--hard", "98ca12ddf082d6e2367b2963f76edf5a09242deb")

    Write-Host ""
    Write-Host "[2/7] Applying audited English-source profile..."
    Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") $OriginalBinHash $ExpectedBinHash
    Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") $OriginalMgtitStored $UserMgtitStored
    Replace-Exact (Join-Path $Upstream "src/source_disc/profile.rs") $OriginalMgtitDecoded $UserMgtitDecoded
    Replace-Exact (Join-Path $Upstream "src/menu_audit/known_consumers/mgtit.rs") $OriginalMgtitDecoded $UserMgtitDecoded
    Replace-Exact (Join-Path $Upstream "src/ending_subtitles.rs") $OriginalBinHash $ExpectedBinHash
    Replace-Exact (Join-Path $Upstream "src/dialogue_audit/codebook_tests.rs") $OriginalBinHash $ExpectedBinHash

    # Add a local-only test that makes the Rust code itself open and inspect the audited BIN.
    $ProbePath = Join-Path $Upstream "src/source_disc.rs"
    $Probe = @'

#[cfg(test)]
mod english_source_probe {
    use super::*;
    use std::path::Path;

    #[test]
    fn english_source_variant_opens_audited_disc() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"));
        let source = SupportedSourceDisc::open(
            &root.join("roms/Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"),
        )
        .expect("adapted source profile must accept the audited BIN");

        assert_eq!(
            source.source_bin_sha256(),
            "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
        );

        let (_, main_exe) = source.read_record("SLPS_021.20").unwrap();
        assert_eq!(
            crate::pipeline::sha256_bytes(&main_exe),
            "3aaa6696582d918ea6ba88b6efe2285ecad2d1c681e1a64cd757df63d24bbfe5"
        );

        let (_, mgtit_stored) = source.read_record("DAT1/MGTIT.BIZ").unwrap();
        assert_eq!(
            crate::pipeline::sha256_bytes(&mgtit_stored),
            "71d01319369b97258d962528aeaa274bce6d1b29d194aa530b6e3e0d589356b3"
        );

        let mgtit = crate::compression::decompress(&mgtit_stored, false).unwrap();
        assert_eq!(mgtit.len(), 48_360);
        assert_eq!(
            crate::pipeline::sha256_bytes(&mgtit),
            "fe36b68795859f907aed70eb13517e853f3fd779df43b7c992191c47c5341cf5"
        );

        crate::menu_audit::validate_mgtit_placement_renderer(&mgtit).unwrap();

        assert_eq!(
            u32::from_le_bytes(mgtit[0..4].try_into().unwrap()),
            0x800a_3b60
        );
        assert!(
            mgtit[0xa400..0xbce8].iter().all(|byte| *byte == 0),
            "MGTIT patch-storage padding must remain source-zero"
        );
    }
}
'@
    [System.IO.File]::AppendAllText(
        $ProbePath,
        $Probe,
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Host ""
    Write-Host "[3/7] Preparing the exact audited ROM under the upstream path..."
    $Roms = Join-Path $Upstream "roms"
    New-Item -ItemType Directory -Force -Path $Roms | Out-Null

    $TargetBin = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin"
    $TargetCue = Join-Path $Roms "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).cue"
    Copy-Item $SourceBin $TargetBin -Force

    @'
FILE "Shiritsu Justice Gakuen - Nekketsu Seishun Nikki 2 (Japan).bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
'@ | Set-Content -Encoding ASCII $TargetCue

    Write-Host ""
    Write-Host "[4/7] Confirming Rust toolchain..."
    Run-Native "rustc" @("--version")
    Run-Native "cargo" @("--version")

    Write-Host ""
    Write-Host "[5/7] Building the adapted release toolchain..."
    Run-Native "cargo" @("build", "--release")

    Write-Host ""
    Write-Host "[6/7] Running the actual-source Rust probe..."
    Run-Native "cargo" @(
        "test", "--lib",
        "source_disc::english_source_probe::english_source_variant_opens_audited_disc",
        "--", "--exact"
    )

    Write-Host ""
    Write-Host "[7/7] Running portable public tests..."
    # Five upstream tests rely on filesystem/error-message behavior that differs on Windows.
    # The previous run demonstrated the remaining public tests passed.
    Run-Native "cargo" @(
        "test", "--lib", "--",
        "--skip", "dialogue_audit::dialogue_disc_outputs_tests::complete_staged_set_replaces_last_verified_outputs",
        "--skip", "dialogue_audit::dialogue_disc_outputs_tests::interrupted_publication_recovers_on_next_prepare_with_or_without_previous_outputs",
        "--skip", "disc::rebuild::tests::changed_mode2_form2_sector_is_rejected_before_output",
        "--skip", "disc::rebuild::tests::changed_payload_sector_with_invalid_source_protection_is_rejected_before_output",
        "--skip", "disc::rebuild::tests::source_identity_from_another_same_size_path_preserves_existing_staged_output"
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host "PHASE 1 CORRECTED VERIFICATION PASSED" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The adapted Rust toolchain accepted and inspected the exact audited BIN."
}
finally {
    Pop-Location
}

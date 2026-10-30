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
    $CandidateRoot = Join-Path $RecoveryRoot "candidates"
    if (Test-Path -LiteralPath $CandidateRoot -PathType Container) {
        $Folders = @(Get-ChildItem -LiteralPath $CandidateRoot -Directory -Filter "status-diary-v28-*" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Folder in $Folders) {
            $Candidate = Join-Path $Folder.FullName "build/justice-gakuen2-status-diary-v28.bin"
            if ((Test-Path -LiteralPath $Candidate -PathType Leaf) -and (Hash $Candidate) -eq "47ed14e1936a0072be400dcdd41296be264ab8bdc1ddcff0e4e7be3bfdc4902b") {
                $MasterBin = $Candidate
                break
            }
        }
    }
    if (-not $MasterBin) { throw "No verified v28 candidate found. Pass -MasterBin with the v28 BIN from your successful build." }
}
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/boot-notice-v29-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/dialogue_audit/name_entry_input_tests.rs"
$ExpectedMasterHash = "47ed14e1936a0072be400dcdd41296be264ab8bdc1ddcff0e4e7be3bfdc4902b"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "name_entry_input_tests.pre-v29.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v29.log"
Write-Host "Justice Gakuen English Project - BOOT NOTICE ENGLISH v29" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v28 master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }

$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_BOOT_NOTICE_V29")) { throw "Previous v29 injection remains. Restore its exact source backup before retrying." }
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v28 input: " + $MasterBin)
Write-Host "Verified original and v28 images, source availability, output ownership and free space."
if ($CheckOnly) { Write-Host "Preflight passed. No files changed."; return }
$Rust = @'
// ENGLISH_PROJECT_BOOT_NOTICE_V29
mod english_boot_notice_v29 {
 use anyhow::{Result,ensure,Context};
 use std::{fs,path::PathBuf,collections::BTreeSet};
 use crate::{disc::rebuild,pipeline::{sha256_file,sha256_bytes}};
 const MASTER:&str="47ed14e1936a0072be400dcdd41296be264ab8bdc1ddcff0e4e7be3bfdc4902b";
 const SOURCE:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 fn patch(before:&[u8],original:&[u8],delta:usize)->Result<Vec<u8>> {
  ensure!(before.len()==original.len(),"record length changed");let mut after=before.to_vec();let mut owned=BTreeSet::new();
  for (at,count,text) in [(0x6a4usize,10usize,"NO FILE"),(0xaa0,13,"LOAD SKIPPED")] {
   let p=delta+at;let n=u16::from_le_bytes(original[p..p+2].try_into()?) as usize;ensure!(n==count,"source message size changed");let end=p+2+2*n;ensure!(before[p..end]==original[p..end],"target already customized");
   let codes=text.chars().map(|c|crate::text::common_menu_ascii_glyph_code(c).context("unsupported resident English glyph")).collect::<Result<Vec<_>>>()?;ensure!(codes.len()<=n,"message does not fit native slot");
   after[p..p+2].copy_from_slice(&(codes.len()as u16).to_le_bytes());for(i,c)in codes.iter().enumerate(){after[p+2+2*i..p+4+2*i].copy_from_slice(&c.to_le_bytes());}owned.extend(p..end);
  }
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||owned.contains(&i)),"write escaped string slots");Ok(after)
 }
 fn run()->Result<()> {
  let master=PathBuf::from(std::env::var("JG2_V29_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V29_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V29_OUTPUT")?);ensure!(sha256_file(&master)?==MASTER&&sha256_file(&source)?==SOURCE,"input identity");ensure!(!out.exists(),"output exists");
  let mut data=Vec::new();for(path,delta)in[("DAT1/NEWOPT.BIN",0usize),("SLPS_021.20",0x801f0)]{let current=rebuild::read_record(&master,path)?.1;let original=rebuild::read_record(&source,path)?.1;data.push((path,patch(&current,&original,delta)?));}
  let overlay=rebuild::read_record(&source,"DAT1/NEWOPT.BIN")?.1;let main=rebuild::read_record(&source,"SLPS_021.20")?.1;for(at,count)in[(0x6a4,10),(0xaa0,13)]{ensure!(overlay[at..at+2+count*2]==main[at+0x801f0..at+0x801f0+2+count*2],"resident mirror binding changed");}
  fs::create_dir_all(&out)?;let bin=out.join("justice-gakuen2-boot-notice-v29.bin");let repl=data.iter().map(|(p,d)|rebuild::FixedRecordReplacement{path:p,data:d}).collect::<Vec<_>>();let records=rebuild::copy_and_replace_records(&master,&bin,&repl)?;for r in &repl{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback");}let allowed=records.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|l|allowed.contains(l)),"sector ownership");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector integrity");}
  ensure!(sha256_file(&master)?==MASTER&&sha256_file(&source)?==SOURCE,"input changed");let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-boot-notice-v29.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
  let report=serde_json::json!({"kind":"Boot notice English v29","master_sha256":MASTER,"source_sha256":SOURCE,"output_sha256":hash,"cue":cue,"changed_sector_count":changed.len(),"messages":2,"record_copies":4,"code_fonts_pointers_and_other_bytes_preserved":true,"records":data.iter().map(|(p,d)|serde_json::json!({"path":p,"sha256":sha256_bytes(d)})).collect::<Vec<_>>()});fs::write(out.join("boot-notice-v29-report.json"),serde_json::to_vec_pretty(&report)?)?;println!("BOOT_NOTICE_V29_COMPLETE=1\nOUTPUT_SHA256={hash}\nCUE={}",cue.display());Ok(())
 }
 #[test]fn english_project_boot_notice_v29()->Result<()>{run()}
 #[test]fn english_project_boot_notice_v29_preservation()->Result<()>{let source=PathBuf::from(std::env::var("JG2_V29_SOURCE")?);let original=rebuild::read_record(&source,"DAT1/NEWOPT.BIN")?.1;let mut customized=original.clone();customized[0x6a6]^=1;ensure!(patch(&customized,&original,0).is_err(),"custom target overwritten");let mut current=original.clone();current[0x50]^=1;let changed=patch(&current,&original,0)?;ensure!(changed[0x50]==current[0x50],"unowned prior change lost");for(at,expected)in [(0x6a4,7),(0xaa0,12)]{ensure!(u16::from_le_bytes(changed[at..at+2].try_into()?)==expected,"length prefix");}Ok(())}
}

'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V29_MASTER","JG2_V29_SOURCE","JG2_V29_OUTPUT")) {
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
    $env:JG2_V29_MASTER = $MasterBin
    $env:JG2_V29_SOURCE = $SourceBin
    $env:JG2_V29_OUTPUT = $BuildDir
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building the startup notice and its shared Records copies..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_boot_notice_v29 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v29 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "boot-notice-v29-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-boot-notice-v29.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.messages -ne 2 -or $Report.record_copies -ne 4 -or -not $Report.code_fonts_pointers_and_other_bytes_preserved) { throw "Report scope verification failed." }
if ((Get-Item -LiteralPath $OutputBin).Length -ne $ExpectedDiscBytes -or (Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output length/hash differs from the build report." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "BOOT NOTICE ENGLISH v29 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host "Startup: NO FILE / LOAD SKIPPED. Shared Records copies updated."
Write-Host "Code, fonts, pointers, save behavior and earlier English preserved."
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v28. Fresh-boot the new CUE and check the startup notice."
Write-Host "Exam instruction graphics and other save/load prompts remain outside this build."

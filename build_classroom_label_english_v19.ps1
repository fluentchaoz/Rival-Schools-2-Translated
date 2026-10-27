[CmdletBinding()]
param(
    [string]$RecoveryRoot = "",
    [string]$MasterBin = "",
    [string]$SourceBin = "",
    [string]$UpstreamRoot = "",
    [string]$WorkRoot = "",
    [string]$FontPath = "",
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
        $Folders = @(Get-ChildItem -LiteralPath $CandidateRoot -Directory -Filter "stat-results-v18-*" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Folder in $Folders) {
            $Candidate = Join-Path $Folder.FullName "build/justice-gakuen2-stat-results-v18.bin"
            if ((Test-Path -LiteralPath $Candidate -PathType Leaf) -and (Hash $Candidate) -eq "d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068") {
                $MasterBin = $Candidate
                break
            }
        }
    }
    if (-not $MasterBin) { throw "No verified v18 candidate found. Pass -MasterBin with the v18 BIN from your successful build." }
}
if (-not $FontPath) { $FontPath = "C:\Windows\Fonts\arial.ttf" }
$FontPath = FullPath $FontPath
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/classroom-label-v19-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/diary_scene/runtime_bundle_build.rs"
$ExpectedMasterHash = "d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "runtime_bundle_build.pre-v19.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v19.log"
Write-Host "Justice Gakuen English Project - CLASSROOM LABEL ENGLISH v19" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,$FontPath,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v18 master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }
$OriginalFontHash = Hash $FontPath
$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_CLASSROOM_LABEL_V19")) {
    throw "A previous v19 source injection remains. Restore runtime_bundle_build.pre-v19.rs.bak from that run's candidate folder before retrying."
}
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v18 input: " + $MasterBin)
Write-Host "Verified original and v18 images, font, source availability, output ownership, and free space." -ForegroundColor Green
if ($CheckOnly) { Write-Host "Preflight passed. No files changed." -ForegroundColor Green; return }
$Rust = @'
// ENGLISH_PROJECT_CLASSROOM_LABEL_V19
mod english_classroom_v19 {
    use anyhow::{Context, Result, ensure};
    use serde_json::{Value, json};
    use std::{fs, io::BufWriter, path::{Path, PathBuf}};
    use crate::{compression::decompress, disc::rebuild, pipeline::{sha256_bytes, sha256_file}};
    use crate::tim::{Cell, read_8bpp_indexed_cell_in_prefix, read_8bpp_palette_words_in_prefix, write_8bpp_indexed_cell_in_prefix};

    const MASTER_HASH: &str = "d720ea2ae3c2c1c52981b0536642b836ec8e2151c6e94b658abdd1a49e094068";
    const SOURCE_HASH: &str = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
    const RECORD: &str = "DAT2/MGBGK04.BZZ";
    const MASTER_ARCHIVE_HASH: &str = "f418235d0a1d714ae1d63e88d254ffe42d034db9e3eb54e64892f261b92c5277";
    const SOURCE_ARCHIVE_HASH: &str = "c45932c3ae22706250f3db1c000d9f8911a475083bd74e485c6daebbb3167558";
    const MEMBER_COMPRESSED_HASH: &str = "6b807a50bf631b350ef4086ccdb8e0ea9c838627877e0e5773908295e1036c5d";
    const MEMBER_DECODED_HASH: &str = "05c1aa75c4ebf24f7dc6623576565cd9adef9886913d006bda2a3cdd0877471d";
    const TIM_HASH: &str = "d07eac0aedbecf52ec68b896cce9f660c1d24bc6fd5f48aa0c10a5a039baf29f";
    const LABEL_HASH: &str = "11ca7aa45d9787c49e89d7c1e7c4f59e0003a7bdd506c12d78383d7df290f09e";
    const LABEL: Cell = Cell {x:0, y:220, width:128, height:24};
    const TEXT: Cell = Cell {x:4, y:220, width:76, height:24};

    struct Built { archive: Vec<u8>, decoded: Vec<u8>, report: Value }

    // Render from the user's installed font. Keep its hash in the report and
    // use integer geometry checks; no font or game artwork is distributed.
    fn raster(font: &fontdue::Font, size: f32) -> Result<(Vec<u8>, [usize;4])> {
        let mut cursor = 0.0_f32;
        let mut points = Vec::new();
        for ch in "CLASSROOM".chars() {
            let (m, coverage) = font.rasterize(ch, size);
            ensure!(coverage.iter().any(|v| *v >= 96), "font lacks a visible {ch}");
            let x = cursor.round() as i32 + m.xmin;
            let y = -m.ymin - m.height as i32;
            for gy in 0..m.height { for gx in 0..m.width {
                if coverage[gy*m.width+gx] >= 96 { points.push((x+gx as i32,y+gy as i32)); }
            }}
            cursor += m.advance_width;
        }
        let min_x = points.iter().map(|p|p.0).min().context("empty text")?;
        let max_x = points.iter().map(|p|p.0).max().unwrap();
        let min_y = points.iter().map(|p|p.1).min().unwrap();
        let max_y = points.iter().map(|p|p.1).max().unwrap();
        let width = (max_x-min_x+3) as usize;
        let height = (max_y-min_y+3) as usize;
        ensure!(width <= TEXT.width && height <= TEXT.height, "CLASSROOM at {size}px exceeds the visible banner");
        let y_pad = (TEXT.height-height)/2;
        let mut pixels = vec![0u8; TEXT.width*TEXT.height];
        for &(x,y) in &points {
            let x = (x-min_x+1) as usize;
            let y = (y-min_y+1) as usize+y_pad;
            for dy in y-1..=y+1 { for dx in x-1..=x+1 { pixels[dy*TEXT.width+dx]=1; }}
        }
        for (x,y) in points {
            let x = (x-min_x+1) as usize;
            let y = (y-min_y+1) as usize+y_pad;
            pixels[y*TEXT.width+x]=228;
        }
        Ok((pixels,[TEXT.x,TEXT.y+y_pad,TEXT.x+width,TEXT.y+y_pad+height]))
    }

    fn patch_record(master: &[u8], source: &[u8], font_bytes: &[u8]) -> Result<Built> {
        ensure!(sha256_bytes(source)==SOURCE_ARCHIVE_HASH,"original MGBGK04 identity changed");
        let slots = crate::tzz::parse_tzz(master)?;
        let original_slots = crate::tzz::parse_tzz(source)?;
        ensure!(slots==original_slots && slots.len()==3,"MGBGK04 archive geometry changed");
        let slot = slots[1];
        let compressed = &master[slot.compressed_range()];
        ensure!(compressed==&source[slot.compressed_range()],"classroom member already contains another patch");
        ensure!(sha256_bytes(compressed)==MEMBER_COMPRESSED_HASH,"classroom compressed identity changed");
        let before = decompress(compressed,false)?;
        ensure!(before.len()==303104 && sha256_bytes(&before)==MEMBER_DECODED_HASH,"classroom decoded identity changed");
        let tim = crate::embedded_tim::parse_embedded_tim_at(&before,0)?;
        ensure!(tim.source_tim_sha256==TIM_HASH && tim.pixel_width==256 && tim.pixel_height==244 && tim.bits_per_pixel==8,"classroom texture geometry changed");
        let old_label = read_8bpp_indexed_cell_in_prefix(&before,0,LABEL)?;
        ensure!(sha256_bytes(&old_label)==LABEL_HASH,"classroom label pixels changed");
        let palette = read_8bpp_palette_words_in_prefix(&before,0,0)?;
        ensure!(palette[0]==0x8000 && palette[1]==0x1084 && palette[228]==0x7fff,"classroom palette changed");
        let font = fontdue::Font::from_bytes(font_bytes,fontdue::FontSettings::default())
            .map_err(|e|anyhow::anyhow!("cannot load the selected font: {e}"))?;
        let mut selected = None;
        for size in [12.0_f32,11.0,10.0] {
            if let Ok((pixels,bounds))=raster(&font,size) { selected=Some((size,pixels,bounds));break; }
        }
        let (font_px,pixels,bounds)=selected.context("CLASSROOM did not fit at 12, 11, or 10 pixels")?;
        ensure!(bounds[2]<=80,"CLASSROOM escapes the established visible width");
        let mut after = before.clone();
        let allowed = write_8bpp_indexed_cell_in_prefix(&mut after,0,LABEL,&vec![0;LABEL.width*LABEL.height])?;
        write_8bpp_indexed_cell_in_prefix(&mut after,0,TEXT,&pixels)?;
        ensure!(after!=before,"banner patch made no change");
        ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))| a==b || allowed.iter().any(|r|i>=r[0] && i<r[1])),"decoded change escaped the banner");
        ensure!(before[..544+220*256]==after[..544+220*256],"palette, header, or classroom background changed");
        ensure!(before[tim.total_size..]==after[tim.total_size..],"portraits or trailing graphics changed");
        let encoding = super::encode_runtime_member(compressed,&before,&after)?;
        ensure!(encoding.compression_requirement_satisfied,"native compression contract failed");
        let length=encoding.bytes.len();
        ensure!(length<=slot.compressed_size,"classroom member exceeds its fixed compressed slot");
        let mut stored=encoding.bytes;
        ensure!(decompress(&stored,false)?==after,"compression round trip failed");
        stored.resize(slot.compressed_size,0);
        ensure!(decompress(&stored,true)?==after,"padded stream readback failed");
        let mut archive=master.to_vec();archive[slot.compressed_range()].copy_from_slice(&stored);
        ensure!(crate::tzz::parse_tzz(&archive)?==slots,"archive geometry changed");
        ensure!(archive[..slot.offset]==master[..slot.offset] && archive[slot.offset+slot.compressed_size..]==master[slot.offset+slot.compressed_size..],"another member or archive padding changed");
        let new_label=read_8bpp_indexed_cell_in_prefix(&after,0,LABEL)?;
        let changed_pixels=old_label.iter().zip(&new_label).filter(|(a,b)|a!=b).count();
        let report=json!({"kind":"Justice Gakuen 2 CLASSROOM banner English v19","record_path":RECORD,"member_index":1,"tim_offset":0,"english_text":"CLASSROOM","source_archive_sha256":SOURCE_ARCHIVE_HASH,"input_archive_sha256":sha256_bytes(master),"patched_archive_sha256":sha256_bytes(&archive),"source_member_decoded_sha256":MEMBER_DECODED_HASH,"patched_member_decoded_sha256":sha256_bytes(&after),"source_label_sha256":LABEL_HASH,"patched_label_sha256":sha256_bytes(&new_label),"font_sha256":sha256_bytes(font_bytes),"font_px":font_px,"ink_bounds":bounds,"visible_right_exclusive":80,"clear_index":0,"outline_index":1,"fill_index":228,"changed_indexed_pixels":changed_pixels,"compressed_bytes":length,"fixed_compressed_slot":slot.compressed_size,"archive_bytes":archive.len(),"native_compression_contract_preserved":true,"palette_background_portraits_preserved":true,"school_gate_and_quiz_graphics_preserved":true});
        Ok(Built{archive,decoded:after,report})
    }

    fn preview(path: &Path, decoded: &[u8]) -> Result<()> {
        let indexed=read_8bpp_indexed_cell_in_prefix(decoded,0,LABEL)?;
        let palette=read_8bpp_palette_words_in_prefix(decoded,0,0)?;
        let (width,height)=(LABEL.width*4,LABEL.height*4);
        let mut rgba=Vec::with_capacity(width*height*4);
        for y in 0..height { for x in 0..width {
            let index=indexed[(y/4)*LABEL.width+x/4];let v=palette[usize::from(index)];
            let expand=|v:u16|((v*255+15)/31) as u8;
            rgba.extend_from_slice(&[expand(v&31),expand((v>>5)&31),expand((v>>10)&31),if index==0 {0}else{255}]);
        }}
        let mut encoder=png::Encoder::new(BufWriter::new(fs::File::create(path)?),width as u32,height as u32);
        encoder.set_color(png::ColorType::Rgba);encoder.set_depth(png::BitDepth::Eight);
        encoder.write_header()?.write_image_data(&rgba)?;Ok(())
    }
    fn outdir() -> Result<PathBuf> {
        let p=PathBuf::from(std::env::var("JG2_V19_OUTPUT")?);
        ensure!(!p.exists(),"output directory already exists");fs::create_dir_all(&p)?;Ok(p)
    }
    fn build_disc() -> Result<()> {
        let master=PathBuf::from(std::env::var("JG2_V19_MASTER")?);
        let source=PathBuf::from(std::env::var("JG2_V19_SOURCE")?);
        let font=fs::read(std::env::var("JG2_V19_FONT")?)?;
        ensure!(sha256_file(&master)?==MASTER_HASH,"v18 master SHA mismatch");
        ensure!(sha256_file(&source)?==SOURCE_HASH,"original disc SHA mismatch");
        let (_,current)=rebuild::read_record(&master,RECORD)?;
        ensure!(sha256_bytes(&current)==MASTER_ARCHIVE_HASH,"v18 MGBGK04 archive SHA mismatch");
        let (_,original)=rebuild::read_record(&source,RECORD)?;
        let (_,quiz)=rebuild::read_record(&master,"DAT2/MGK04.BIZ")?;
        ensure!(sha256_bytes(&quiz)=="91ca0e81829fb578d41797854718590e0f05e29b1325b6a1675e9df3a4584fa0","v18 quiz/stat layer changed");
        let mut built=patch_record(&current,&original,&font)?;
        let out=outdir()?;let bin=out.join("justice-gakuen2-classroom-label-v19.bin");let cue=bin.with_extension("cue");
        let replaced=rebuild::copy_and_replace_record(&master,&bin,RECORD,&built.archive)?;
        ensure!(rebuild::read_record(&bin,RECORD)?.1==built.archive,"archive disc readback failed");
        ensure!(rebuild::read_record(&bin,"DAT2/MGK04.BIZ")?.1==quiz,"quiz or stat messages changed");
        let (changed,output_hash)=rebuild::compare_and_hash_images(&master,&bin)?;
        ensure!(!changed.is_empty() && changed.iter().all(|lba|replaced.target_lbas.contains(lba)),"changed sectors escaped MGBGK04");
        let mut track=crate::disc::RawTrack::open(&bin)?;
        for lba in &changed {ensure!(crate::disc::mode2::verify(&track.raw_sector(*lba)?),"EDC/ECC verification failed at {lba}");}
        ensure!(sha256_file(&master)?==MASTER_HASH && sha256_file(&source)?==SOURCE_HASH,"input image changed during build");
        fs::write(&cue,"FILE \"justice-gakuen2-classroom-label-v19.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
        let png=out.join("classroom-label-v19-preview.png");preview(&png,&built.decoded)?;
        built.report["master_sha256"]=json!(MASTER_HASH);built.report["source_sha256"]=json!(SOURCE_HASH);
        built.report["output_sha256"]=json!(output_hash);built.report["changed_sector_count"]=json!(changed.len());built.report["changed_lbas"]=json!(changed);
        built.report["quiz_and_stat_messages_preserved"]=json!(true);built.report["cue"]=json!(cue.display().to_string());
        fs::write(out.join("classroom-label-v19-report.json"),serde_json::to_vec_pretty(&built.report)?)?;
        eprintln!("CLASSROOM_LABEL_V19_COMPLETE=1\nOUTPUT_SHA256={output_hash}\nCHANGED_RAW_SECTORS={}\nCOMPRESSED_SIZE={}\nCUE={}",changed.len(),built.report["compressed_bytes"],cue.display());Ok(())
    }
    #[test]
    fn english_project_classroom_label_v19() -> Result<()> {
        match std::thread::Builder::new().name("classroom-v19-builder".into()).stack_size(64*1024*1024).spawn(build_disc)?.join() {
            Ok(result)=>result,Err(panic)=>std::panic::resume_unwind(panic)
        }
    }
    #[test]
    #[ignore="requires private original records and a local font"]
    fn classroom_label_v19_record_fixture() -> Result<()> {
        let source=fs::read(std::env::var("JG2_V19_FIXTURE")?)?;
        let font=fs::read(std::env::var("JG2_V19_FONT")?)?;
        let mut master=source.clone();let slots=crate::tzz::parse_tzz(&master)?;
        // Opaque sentinels stand in for earlier changes to other members.
        // They are never decoded or distributed as a playable archive.
        master[slots[0].offset+100]^=0x5a;master[slots[2].offset+100]^=0xa5;
        let built=patch_record(&master,&source,&font)?;
        let out=outdir()?;fs::write(out.join("MGBGK04.BZZ"),&built.archive)?;
        fs::write(out.join("member1.decoded"),&built.decoded)?;
        fs::write(out.join("report.json"),serde_json::to_vec_pretty(&built.report)?)?;
        preview(&out.join("preview.png"),&built.decoded)?;
        eprintln!("{}",serde_json::to_string_pretty(&built.report)?);Ok(())
    }
}

'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V19_MASTER","JG2_V19_SOURCE","JG2_V19_OUTPUT","JG2_V19_FONT")) {
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
    $env:JG2_V19_MASTER = $MasterBin
    $env:JG2_V19_SOURCE = $SourceBin
    $env:JG2_V19_OUTPUT = $BuildDir
    $env:JG2_V19_FONT = $FontPath
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building the English CLASSROOM banner and verifying the candidate..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_classroom_label_v19 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v19 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "classroom-label-v19-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-classroom-label-v19.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
$Preview = Join-Path $BuildDir "classroom-label-v19-preview.png"
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue,$Preview)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.english_text -ne "CLASSROOM" -or -not $Report.quiz_and_stat_messages_preserved -or -not $Report.school_gate_and_quiz_graphics_preserved -or -not $Report.palette_background_portraits_preserved) { throw "Final report scope verification failed." }
if ((Get-Item -LiteralPath $OutputBin).Length -ne $ExpectedDiscBytes -or (Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output length/hash differs from the build report." }
if ((Hash $FontPath) -ne $OriginalFontHash -or $Report.font_sha256 -ne $OriginalFontHash) { throw "Font identity changed during the build." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "CLASSROOM LABEL ENGLISH v19 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host ("Changed raw sectors: " + $Report.changed_sector_count)
Write-Host ("Classroom member compressed bytes: {0} / {1}" -f $Report.compressed_bytes,$Report.fixed_compressed_slot)
Write-Host ("Font size: {0}px; palette clear=0 outline=1 fill=228" -f $Report.font_px)
Write-Host "Classroom background, portraits, School Gate, quiz graphics, and v18 stat messages preserved."
Write-Host ""
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("PREVIEW: " + $Preview)
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v18. Boot this new CUE fresh and check CLASSROOM beneath the stats, then continue through the quiz and stat results."
Write-Host "This candidate changes the MGK04 classroom banner; other location copies may still contain Japanese."

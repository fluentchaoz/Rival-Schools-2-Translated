[CmdletBinding()]
param(
    [string]$RecoveryRoot = "",
    [string]$MasterBin = "",
    [string]$SourceBin = "",
    [string]$UpstreamRoot = "",
    [string]$WorkRoot = "",
    [string]$FontPath = "",
    [string]$PacketPath = "",
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
        $Folders = @(Get-ChildItem -LiteralPath $CandidateRoot -Directory -Filter "locations-names-v25-*" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Folder in $Folders) {
            $Candidate = Join-Path $Folder.FullName "build/justice-gakuen2-locations-names-v25.bin"
            if ((Test-Path -LiteralPath $Candidate -PathType Leaf) -and (Hash $Candidate) -eq "5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453") {
                $MasterBin = $Candidate
                break
            }
        }
    }
    if (-not $MasterBin) { throw "No verified v25 candidate found. Pass -MasterBin with the v25 BIN from your successful build." }
}
if (-not $FontPath) { $FontPath = "C:\Windows\Fonts\arial.ttf" }
$FontPath = FullPath $FontPath
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/shared-dates-v26-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/dialogue_audit/name_entry_input_tests.rs"
$ExpectedMasterHash = "5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "name_entry_input_tests.pre-v26.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v26.log"
Write-Host "Justice Gakuen English Project - SHARED DATES AND DAILY NARRATION ENGLISH v26" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,$FontPath,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v25 master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }

$ExpectedPacketHash = "714f77e8112daed6585e5912a5e312b8093229bbd13ad1cce9fdafb521cebfa6"
function HashBytes([byte[]]$Data) {
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Hasher.ComputeHash($Data))).Replace("-","").ToLowerInvariant() } finally { $Hasher.Dispose() }
}
function Read-PrivatePacket([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing private packet or ZIP: $Path" }
    if ([IO.Path]::GetExtension($Path) -ieq ".zip") {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $Archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $Entry = $Archive.GetEntry("shared_daily_dates_v26.json")
            if ($null -eq $Entry -or $Entry.Length -gt 2MB) { throw "ZIP does not contain the expected bounded v26 packet." }
            $Stream = $Entry.Open(); $Memory = [IO.MemoryStream]::new()
            try { $Stream.CopyTo($Memory); [byte[]]$Data = $Memory.ToArray() } finally { $Stream.Dispose(); $Memory.Dispose() }
        } finally { $Archive.Dispose() }
    } else {
        if ((Get-Item -LiteralPath $Path).Length -gt 2MB) { throw "Private packet exceeds size limit." }
        [byte[]]$Data = [IO.File]::ReadAllBytes($Path)
    }
    if ((HashBytes $Data) -ne $ExpectedPacketHash) { throw "Private packet hash mismatch: $Path" }
    return ,$Data
}
[byte[]]$PacketBytes = $null
if ($PacketPath) {
    $PacketPath = FullPath $PacketPath
    $PacketBytes = Read-PrivatePacket $PacketPath
} else {
    foreach ($Folder in @((Join-Path $RecoveryRoot "private-inputs"),(Join-Path $env:USERPROFILE "Downloads"),$PSScriptRoot)) {
        if (-not $Folder -or -not (Test-Path -LiteralPath $Folder -PathType Container)) { continue }
        $Direct = Join-Path $Folder "shared_daily_dates_v26.json"
        $Candidates = @()
        if (Test-Path -LiteralPath $Direct -PathType Leaf) { $Candidates += Get-Item -LiteralPath $Direct }
        $Candidates += @(Get-ChildItem -LiteralPath $Folder -File -Filter "JG2-Shared-Dates-v26-Inputs*.zip" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Candidate in $Candidates) {
            try { $PacketBytes = Read-PrivatePacket $Candidate.FullName; $PacketPath = $Candidate.FullName; break } catch { $PacketBytes = $null }
        }
        if ($null -ne $PacketBytes) { break }
    }
    if ($null -eq $PacketBytes) { throw "Download JG2-Shared-Dates-v26-Inputs.zip from the translation conversation into Downloads, or pass -PacketPath with that ZIP or the exact shared_daily_dates_v26.json. No game or source files changed." }
}
Write-Host ("Verified private v26 translation input: " + $PacketPath)

$OriginalFontHash = Hash $FontPath
$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_SHARED_DATES_V26")) {
    throw "A previous v26 source injection remains. Restore name_entry_input_tests.pre-v26.rs.bak from that run's candidate folder before retrying."
}
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v25 input: " + $MasterBin)
Write-Host "Verified original and v25 images, private packet, font, source availability, output ownership, and free space." -ForegroundColor Green
if ($CheckOnly) { Write-Host "Preflight passed. No files changed." -ForegroundColor Green; return }
$Rust = @'
// ENGLISH_PROJECT_SHARED_DATES_V26
mod english_shared_dates_v26 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde::Deserialize;
 use serde_json::{json,Value};
 use super::super::{atlas,tokens};
 use crate::{pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild};
 const MASTER_HASH:&str="5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const PACKET_HASH:&str="714f77e8112daed6585e5912a5e312b8093229bbd13ad1cce9fdafb521cebfa6";
 const ARENA:usize=0x31000;
 const LIMIT:usize=0x4a000;
 type Banks=Vec<(usize,Vec<Vec<u8>>)>;
 #[derive(Deserialize)] struct Packet {source_sha256:String,source_pattern_count:usize,source_coordinate_count:usize,runtime_images:usize,entries:Vec<Entry>}
 #[derive(Deserialize)] struct Entry {id:String,fingerprint:String,coordinate_count:usize,fitted_text:String,protected_controls:Vec<(u16,Vec<u16>)>}
 fn words(b:&[u8])->Vec<u16>{b.chunks_exact(2).map(|p|u16::from_le_bytes([p[0],p[1]])).collect()}
 fn bytes(mut w:Vec<u16>)->Vec<u8>{if w.len()%2!=0{w.push(0);}w.into_iter().flat_map(u16::to_le_bytes).collect()}
 fn u32_at(b:&[u8],at:usize)->Result<u32>{Ok(u32::from_le_bytes(b.get(at..at+4).context("truncated u32")?.try_into()?))}
 fn controls(b:&[u8],fixed:usize,slots:usize)->Result<Vec<(u16,Vec<u16>)>>{
  Ok(tokens::tokenize_dialogue_message(&words(b),fixed,slots)?.tokens.into_iter().filter(|t|!matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph|tokens::DialogueTokenKind::LineBreak|tokens::DialogueTokenKind::SkippedCode)).map(|t|(t.code,t.arguments)).collect())
 }
 // Native messages are pointer-indexed, end-terminated streams. This reader
 // accepts shared payloads while retaining exact 4-byte storage alignment.
 fn pointer_banks(d:&[u8])->Result<Banks>{
  ensure!(d.len()==0x51800,"decoded extent changed");let mut result=Vec::new();
  for sel in 0..8{let table=u32_at(d,ARENA+sel*4)?;if table==0{continue;}let table=table.checked_sub(0x800d0000).context("bad table pointer")? as usize;ensure!((ARENA+32..LIMIT).contains(&table)&&table%4==0,"table outside arena");let mut messages=Vec::new();let mut at=table;
   loop{ensure!(at+4<=LIMIT,"unterminated table");let p=u32_at(d,at)?;at+=4;if p==u32::MAX{break;}let p=p.checked_sub(0x800d0000).context("bad message pointer")? as usize;ensure!((ARENA+32..LIMIT).contains(&p)&&p%4==0,"message outside arena");let mut end=p;
    loop{ensure!(end+2<=LIMIT,"unterminated message");let code=u16::from_le_bytes(d[end..end+2].try_into()?);end+=2;if code==0x3001{break;}if code==0x3002||code==0x3003||(0x2003..=0x2009).contains(&code){ensure!(end+2<=LIMIT,"missing argument");end+=2;}}
    let aligned=(end+3)&!3;ensure!(aligned<=LIMIT&&d[end..aligned].iter().all(|b|*b==0),"invalid alignment padding");messages.push(d[p..aligned].to_vec());
   }result.push((sel,messages));
  }Ok(result)
 }
 fn compact(d:&mut[u8],banks:&Banks)->Result<(usize,usize)>{
  d[ARENA..LIMIT].fill(0);let mut cursor=ARENA+32;let mut pool=BTreeMap::<Vec<u8>,usize>::new();let mut aliases=0;
  for(sel,messages)in banks{let mut ptrs=Vec::new();for m in messages{ensure!(!m.is_empty()&&m.len()%4==0,"unaligned message");let p=if let Some(p)=pool.get(m){aliases+=1;*p}else{ensure!(cursor+m.len()<=LIMIT,"message arena overflow");let p=cursor;d[p..p+m.len()].copy_from_slice(m);cursor+=m.len();pool.insert(m.clone(),p);p};ptrs.push(p);}
   let table=cursor;for p in ptrs{ensure!(cursor+4<=LIMIT,"pointer arena overflow");d[cursor..cursor+4].copy_from_slice(&(0x800d0000+p as u32).to_le_bytes());cursor+=4;}ensure!(cursor+4<=LIMIT,"table terminator overflow");d[cursor..cursor+4].copy_from_slice(&u32::MAX.to_le_bytes());cursor+=4;d[ARENA+sel*4..ARENA+sel*4+4].copy_from_slice(&(0x800d0000+table as u32).to_le_bytes());
  }
  ensure!(pointer_banks(d)?==*banks,"shared message readback differs");Ok((cursor-(ARENA+32),aliases))
 }
 fn assert_pointer_consumer(mgame:&[u8],source:&[u8])->Result<()>{
  super::super::script_message_contract::validate_compact_message_opcode_contract(mgame)?;
  for(off,expected)in [(0xd630,0x96460000u32),(0xd634,0x24023001),(0xd638,0x30c3ffff),(0xd63c,0x106200d2),(0xd640,0x26520002),(0xd974,0x96460000),(0xd978,0x24023001),(0xd97c,0x30c3ffff),(0xd980,0x1462ff35),(0xd984,0x26520002)]{ensure!(u32_at(mgame,off)?==expected&&u32_at(source,off)?==expected,"native end-terminated reader changed");}
  ensure!(mgame[0xd5d0..0xda00]==source[0xd5d0..0xda00],"native message traversal differs");Ok(())
 }
 fn ink(font:&fontdue::Font,text:&str,size:f32)->Result<(usize,usize,Vec<(usize,usize)>)>{
  let mut pts=Vec::new();let mut cursor=0f32;
  for c in text.chars(){let(m,p)=font.rasterize(c,size);if c!=' '{ensure!(p.iter().any(|v|*v>=96),"font lacks {c}");}
   for y in 0..m.height {for x in 0..m.width {if p[y*m.width+x]>=96{pts.push((cursor.round() as i32+m.xmin+x as i32,-m.ymin-m.height as i32+y as i32));}}}cursor+=m.advance_width;
  }
  if pts.is_empty(){return Ok((0,0,vec![]));}
  let minx=pts.iter().map(|p|p.0).min().unwrap();let miny=pts.iter().map(|p|p.1).min().unwrap();
  let w=(pts.iter().map(|p|p.0).max().unwrap()-minx+1) as usize;let h=(pts.iter().map(|p|p.1).max().unwrap()-miny+1) as usize;
  Ok((w,h,pts.into_iter().map(|(x,y)|((x-minx) as usize,(y-miny) as usize)).collect()))
 }
 fn encode_target(text:&str,source:&[u8],codes:&BTreeMap<char,u16>,at:&atlas::ParsedDialogueAtlas)->Result<Vec<u8>>{
  let mut protected=controls(source,at.fixed_cell_count,at.addressable_slot_count)?;ensure!(protected.pop()==Some((0x3001,vec![])),"source terminator changed");let mut w=Vec::new();let mut rest=text;let mut next=0;let mut lines=1;let mut columns=0;
  while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed control placeholder")?;let id=rest[1..end].parse::<usize>()?;ensure!(id==next&&id<protected.len(),"control placeholder order/count");let(code,args)=&protected[id];w.push(*code);w.extend(args);if (0x2000..=0x2009).contains(code){columns+=6;}if [0x200a,0x200b].contains(code){columns+=2;}next+=1;rest=&rest[end+1..];
   }else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c=='\n'{ensure!(columns<=20,"line wider than 20 cells");lines+=1;columns=0;w.push(0x3000);}else{ensure!(c.is_ascii(),"non-ASCII translation");w.push(*codes.get(&c).with_context(||format!("missing ASCII glyph {c}"))?);columns+=1;}}
  }
  ensure!(next==protected.len(),"missing protected control placeholder");ensure!(columns<=20&&lines<=4,"translation exceeds native window");w.push(0x3001);let result=bytes(w);ensure!(controls(&result,at.fixed_cell_count,at.addressable_slot_count)?==controls(source,at.fixed_cell_count,at.addressable_slot_count)?,"protected controls changed");Ok(result)
 }
 fn chars_of(text:&str,set:&mut BTreeSet<char>)->Result<()>{let mut rest=text;while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed placeholder")?;rest=&rest[end+1..];}else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c!='\n'{ensure!(c.is_ascii(),"non-ASCII");set.insert(c);}}}Ok(())}

 fn fingerprint_tokens(d:&[u8],m:&[u8],at:&atlas::ParsedDialogueAtlas)->Result<Vec<Value>>{
  let ts=tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens;
  Ok(ts.into_iter().map(|t|if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){let p=at.pixel_data_offset+t.code as usize*200;json!(["glyph",sha256_bytes(&d[p..p+200])])}else{json!(["control",t.code,t.arguments])}).collect())
 }
 // Ignore only the literal glyph immediately after each runtime month/day.
 // All remaining glyph pixels, control codes and arguments must still match.
 // This admits the earlier slash-only patch while preserving custom prose.
 fn without_date_literals(ts:&[Value])->Vec<Value>{
  let mut result=Vec::new();let mut i=0;
  while i<ts.len(){let t=&ts[i];result.push(t.clone());i+=1;
   if t[0]=="control"&&[Some(0x200a),Some(0x200b)].contains(&t[1].as_u64())&&i<ts.len()&&ts[i][0]=="glyph"{i+=1;}
  }result
 }
 fn tile(font:&fontdue::Font,c:char)->Result<Vec<u8>>{
  let(w,h,pts)=ink(font,&c.to_string(),14.0)?;ensure!(w<=18&&h<=18,"ASCII glyph bounds: {c}");let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;
  for &(x,y)in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}
  for(x,y)in pts{pix[(y+dy)*20+x+dx]=14;}
  Ok(pix.chunks_exact(2).map(|p|p[0]|p[1]<<4).collect())
 }
 fn install_glyphs(before:&[u8],after:&mut[u8],bs:&Banks,at:&atlas::ParsedDialogueAtlas,chars:&BTreeSet<char>,font:&fontdue::Font)->Result<(BTreeMap<char,u16>,Vec<usize>)>{
  let mut used=BTreeSet::new();for(_,ms)in bs{for m in ms{for t in tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){used.insert(t.code as usize);}}}}
  let mut codes=BTreeMap::new();let mut allocated=Vec::new();
  for &c in chars{let pix=tile(font,c)?;
   let found=(0..at.addressable_slot_count).find(|&i|{let p=at.pixel_data_offset+i*200;after[p..p+200]==pix});
   let code=if let Some(i)=found{i}else{
    let i=(at.fixed_cell_count..at.addressable_slot_count).find(|i|!used.contains(i)&&!allocated.contains(i)&&{let p=at.pixel_data_offset+i*200;before[p..p+200].iter().all(|v|*v==0)&&after[p..p+200].iter().all(|v|*v==0)}).with_context(||format!("no empty extension slot for {c}"))?;
    let p=at.pixel_data_offset+i*200;after[p..p+200].copy_from_slice(&pix);allocated.push(i);i
   };codes.insert(c,code as u16);
  }Ok((codes,allocated))
 }
 fn preview(path:&Path,d:&[u8],m:&[u8],at:&atlas::ParsedDialogueAtlas,codes:&BTreeMap<char,u16>)->Result<()>{
  let ts=tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens;
  let mut rgba=vec![0u8;400*80*4];for p in rgba.chunks_exact_mut(4){p.copy_from_slice(&[20,40,45,255]);}let(mut x,mut y)=(0,0);
  for t in ts{if t.code==0x3000{x=0;y+=1;continue;}let glyphs=if [0x200a,0x200b].contains(&t.code){vec![codes[&if t.code==0x200a{'M'}else{'D'}];2]}else if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){vec![t.code]}else{vec![]};
   for g in glyphs{ensure!(x<20&&y<4,"preview exceeds native bounds");let p=at.pixel_data_offset+g as usize*200;for yy in 0..20{for xx in 0..20{let b=d[p+yy*10+xx/2];let v=if xx%2==0{b&15}else{b>>4};if v>0{let q=((y*20+yy)*400+x*20+xx)*4;let color=if v>=8{[255,255,255,255]}else{[20,20,20,255]};rgba[q..q+4].copy_from_slice(&color);}}}x+=1;}
  }let mut png=png::Encoder::new(BufWriter::new(fs::File::create(path)?),400,80);png.set_color(png::ColorType::Rgba);png.set_depth(png::BitDepth::Eight);png.write_header()?.write_image_data(&rgba)?;Ok(())
 }
 fn patch_bank(path:&str,current:&[u8],original:&[u8],font:&fontdue::Font,entries:&BTreeMap<String,Entry>,seen:&mut BTreeMap<String,usize>,previews:&mut BTreeSet<String>,out:&Path)->Result<(Vec<u8>,Value)>{
  let before=decompress(current,true)?;let source=decompress(original,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let sat=atlas::parse_dialogue_atlas(&source)?;ensure!(at.pixel_data_offset==sat.pixel_data_offset&&at.addressable_slot_count==sat.addressable_slot_count,"atlas geometry");
  let old=pointer_banks(&before)?;let src=pointer_banks(&source)?;ensure!(old.iter().map(|(s,m)|(*s,m.len())).collect::<Vec<_>>()==src.iter().map(|(s,m)|(*s,m.len())).collect::<Vec<_>>(),"bank population changed");
  let mut targets=BTreeMap::new();let mut preserved=Vec::new();let mut source_count=0;
  for((sel,ms),(_,sms))in old.iter().zip(&src){for(i,(m,sm))in ms.iter().zip(sms).enumerate(){let st=fingerprint_tokens(&source,sm,&sat)?;if !st.iter().any(|t|t[0]=="control"&&t[1]==0x200a){continue;}ensure!(st.iter().any(|t|t[0]=="control"&&t[1]==0x200b),"month without day");source_count+=1;
   let fp=sha256_bytes(&serde_json::to_vec(&st)?);let entry=entries.get(&fp).context("unreviewed source date pattern")?;*seen.entry(fp.clone()).or_default()+=1;
   ensure!(controls(sm,sat.fixed_cell_count,sat.addressable_slot_count)?.into_iter().filter(|(c,_)|*c!=0x3001).collect::<Vec<_>>()==entry.protected_controls,"packet protected controls differ");
   let ct=fingerprint_tokens(&before,m,&at)?;if without_date_literals(&ct)!=without_date_literals(&st){preserved.push(json!({"selector":sel,"entry":i,"reason":"current custom payload retained byte-for-byte","sha256":sha256_bytes(m)}));continue;}
   targets.insert((*sel,i),fp);
  }}ensure!(source_count==62,"source date population for {path}");
  if targets.is_empty(){return Ok((current.to_vec(),json!({"path":path,"source_dates":source_count,"translated":0,"preserved_custom":preserved})));}
  let mut chars=BTreeSet::new();for fp in targets.values(){chars_of(&entries[fp].fitted_text,&mut chars)?;}chars.extend(['M','D']);let mut after=before.clone();let(codes,allocated)=install_glyphs(&before,&mut after,&old,&at,&chars,font)?;let mut wanted=old.clone();
  for((sel,ms),(_,prior))in wanted.iter_mut().zip(&old){for(i,m)in ms.iter_mut().enumerate(){if let Some(fp)=targets.get(&(*sel,i)){*m=encode_target(&entries[fp].fitted_text,&prior[i],&codes,&at).with_context(||format!("{path} selector {sel} entry {i}"))?;}}}
  let(used,aliases)=compact(&mut after,&wanted)?;let read=pointer_banks(&after)?;ensure!(read==wanted,"pointer readback");
  for((sel,ms),(_,prior))in read.iter().zip(&old){for(i,m)in ms.iter().enumerate(){tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;if !targets.contains_key(&(*sel,i)){ensure!(m==&prior[i],"untargeted payload changed");}}}
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(ARENA..LIMIT).contains(&i)||allocated.iter().any(|g|(at.pixel_data_offset+g*200..at.pixel_data_offset+(g+1)*200).contains(&i))),"change outside arena/new empty glyph cells");
  let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len()).with_context(||format!("fixed compressed slot {path}"))?;let length=stored.len();stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"compressed readback");
  for(&(sel,i),fp)in &targets{if previews.insert(fp.clone()){let m=&read.iter().find(|(s,_)|*s==sel).context("preview selector")?.1[i];preview(&out.join("previews").join(format!("{}.png",entries[fp].id)),&after,m,&at,&codes)?;}}
  if std::env::var_os("JG2_V26_QA_DUMP").is_some(){fs::write(out.join(format!("{}.decoded",Path::new(path).file_stem().unwrap().to_string_lossy())),&after)?;}
  Ok((stored,json!({"path":path,"source_dates":source_count,"translated":targets.len(),"preserved_custom":preserved,"new_glyphs":allocated.len(),"glyph_codes":codes,"arena_used":used,"arena_capacity":LIMIT-ARENA-32,"aliases":aliases,"compressed_bytes":length,"fixed_slot":current.len(),"untargeted_payloads_fonts_and_scripts_preserved":true})))
 }
 fn run()->Result<()>{
  let master=PathBuf::from(std::env::var("JG2_V26_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V26_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V26_OUTPUT")?);let packet_path=PathBuf::from(std::env::var("JG2_V26_PACKET")?);
  ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"disc identity");ensure!(sha256_file(&packet_path)?==PACKET_HASH,"private translation packet identity");ensure!(!out.exists(),"output exists");
  let packet:Packet=serde_json::from_slice(&fs::read(&packet_path)?)?;ensure!(packet.source_sha256==SOURCE_HASH&&packet.source_pattern_count==46&&packet.source_coordinate_count==4836&&packet.runtime_images==78&&packet.entries.len()==46,"packet scope");let entries=packet.entries.into_iter().map(|e|(e.fingerprint.clone(),e)).collect::<BTreeMap<_,_>>();ensure!(entries.len()==46,"duplicate source patterns");
  let fontbytes=fs::read(std::env::var("JG2_V26_FONT")?)?;let font=fontdue::Font::from_bytes(fontbytes.clone(),fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  assert_pointer_consumer(&rebuild::read_record(&master,"DAT1/MGAME.BIN")?.1,&rebuild::read_record(&source,"DAT1/MGAME.BIN")?.1)?;fs::create_dir_all(out.join("previews"))?;
  let originals=super::super::sources::load_dialogue_runtime_image_sources(&source)?;ensure!(originals.len()==78,"runtime population");let mut replacements=BTreeMap::new();let mut reports=Vec::new();let mut seen=BTreeMap::new();let mut previews=BTreeSet::new();
  for s in originals{eprintln!("Shared dates and daily narration: {}",s.path);let current=rebuild::read_record(&master,&s.path)?.1;let(data,report)=patch_bank(&s.path,&current,&s.data,&font,&entries,&mut seen,&mut previews,&out)?;if data!=current{replacements.insert(s.path.clone(),data);}reports.push(report);}
  for(fp,e)in &entries{ensure!(seen.get(fp)==Some(&e.coordinate_count),"source fingerprint coverage {}",e.id);}
  for month in ["04","06","08","09","11"]{let bp=format!("DAT2/MGG{month}.BZZ");let mut bundle=rebuild::read_record(&master,&bp)?.1;let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5,"school bundle geometry");let before=bundle.clone();for(school,slot)in ["T","O","P","G","J"].into_iter().zip(slots){let path=format!("DAT2/MGG{month}{school}.BIZ");let current=rebuild::read_record(&master,&path)?.1;ensure!(bundle[slot.compressed_range()]==current,"loaded bundle binding {path}");if let Some(data)=replacements.get(&path){ensure!(data.len()==slot.compressed_size,"bundle record extent");bundle[slot.compressed_range()].copy_from_slice(data);}}if bundle!=before{replacements.insert(bp,bundle);}}
  let bin=out.join("justice-gakuen2-shared-dates-v26.bin");let repl=replacements.iter().map(|(p,d)|rebuild::FixedRecordReplacement{path:p,data:d}).collect::<Vec<_>>();let changed_records=rebuild::copy_and_replace_records(&master,&bin,&repl)?;for r in &repl{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback");}let allowed=changed_records.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|l|allowed.contains(l)),"changed-sector ownership");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector EDC/ECC");}
  ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH&&sha256_file(&packet_path)?==PACKET_HASH,"input changed");let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-shared-dates-v26.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
  let translated:usize=reports.iter().map(|r|r["translated"].as_u64().unwrap()as usize).sum();let preserved:usize=reports.iter().map(|r|r["preserved_custom"].as_array().unwrap().len()).sum();ensure!(translated+preserved==4836,"coverage accounting");
  let report=json!({"kind":"Shared School Life dates and narration English v26","master_sha256":MASTER_HASH,"source_sha256":SOURCE_HASH,"packet_sha256":PACKET_HASH,"font_sha256":sha256_bytes(&fontbytes),"output_sha256":hash,"cue":cue,"changed_sector_count":changed.len(),"runtime_images":78,"source_patterns":46,"source_date_coordinates":4836,"translated_coordinates":translated,"custom_coordinates_preserved":preserved,"preview_count":previews.len(),"all_other_payloads_and_non_text_records_preserved":true,"records":reports});fs::write(out.join("shared-dates-v26-report.json"),serde_json::to_vec_pretty(&report)?)?;
  println!("SHARED_DATES_V26_COMPLETE=1\nOUTPUT_SHA256={hash}\nTRANSLATED_COORDINATES={translated}\nCUSTOM_COORDINATES_PRESERVED={preserved}\nCHANGED_RAW_SECTORS={}\nCUE={}",changed.len(),cue.display());Ok(())
 }

 #[test] fn english_project_shared_dates_v26_preservation()->Result<()>{
  let source=PathBuf::from(std::env::var("JG2_V26_SOURCE")?);let original=rebuild::read_record(&source,"DAT2/MGC01.BIZ")?.1;let decoded=decompress(&original,true)?;let at=atlas::parse_dialogue_atlas(&decoded)?;let mut old=pointer_banks(&decoded)?;
  let font=fontdue::Font::from_bytes(fs::read(std::env::var("JG2_V26_FONT")?)?,fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  let mut current=decoded.clone();let(codes,_)=install_glyphs(&decoded,&mut current,&old,&at,&BTreeSet::from(['/','Z']),&font)?;
  let ms=&mut old.iter_mut().find(|(s,_)|*s==3).context("test selector")?.1;
  let mut custom=words(&ms[0]);let body=custom.iter().position(|c|*c==0x3000).context("test body")?+1;custom[body]=codes[&'Z'];ms[0]=bytes(custom);let preserved=ms[0].clone();
  let mut slash=words(&ms[1]);slash.truncate(slash.iter().position(|c|*c==0x3001).unwrap()+1);let start=slash.iter().position(|c|*c==0x200a).unwrap();ensure!(slash[start+2]==0x200b,"test date shape");slash[start+1]=codes[&'/'];slash.remove(start+3);ms[1]=bytes(slash);
  compact(&mut current,&old)?;let profile=crate::paged_compression::source_paged_compression_profile(&original)?;let mut encoded=crate::paged_compression::compress_page_safe_image_in_slot(&current,profile,original.len())?;encoded.resize(original.len(),0);
  let packet:Packet=serde_json::from_slice(&fs::read(std::env::var("JG2_V26_PACKET")?)?)?;let entries=packet.entries.into_iter().map(|e|(e.fingerprint.clone(),e)).collect::<BTreeMap<_,_>>();
  let out=std::env::temp_dir().join(format!("jg2-v26-preservation-{}",std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?.as_nanos()));ensure!(!out.exists(),"test path collision");fs::create_dir_all(out.join("previews"))?;
  let(result,report)=patch_bank("DAT2/MGC01.BIZ",&encoded,&original,&font,&entries,&mut BTreeMap::new(),&mut BTreeSet::new(),&out)?;let actual=pointer_banks(&decompress(&result,true)?)?;let ms=&actual.iter().find(|(s,_)|*s==3).unwrap().1;
  ensure!(ms[0]==preserved,"custom prose overwritten");ensure!(report["translated"]==61&&report["preserved_custom"].as_array().unwrap().len()==1,"mixed source/slash/custom accounting");ensure!(ms[1]!=old.iter().find(|(s,_)|*s==3).unwrap().1[1],"slash-only message not translated");fs::remove_dir_all(out)?;Ok(())
 }
 #[test] fn english_project_shared_dates_v26()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(run)?.join().unwrap()}
}

'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V26_MASTER","JG2_V26_SOURCE","JG2_V26_OUTPUT","JG2_V26_FONT","JG2_V26_PACKET","JG2_V26_QA_DUMP")) {
    $SavedEnvironment[$Name] = [Environment]::GetEnvironmentVariable($Name,"Process")
}
[IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
$BackupStream = [IO.File]::Open($Backup,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $BackupStream.Write($OriginalRust,0,$OriginalRust.Length) } finally { $BackupStream.Dispose() }
if ((Hash $Backup) -ne $OriginalRustHash) { throw "Source backup verification failed; source was not edited." }
Write-Host ("Exact source backup: " + $Backup)
$PacketCopy = Join-Path $WorkRoot "shared_daily_dates_v26.json"
[IO.File]::WriteAllBytes($PacketCopy,$PacketBytes)
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
    $env:JG2_V26_MASTER = $MasterBin
    $env:JG2_V26_SOURCE = $SourceBin
    $env:JG2_V26_OUTPUT = $BuildDir
    $env:JG2_V26_FONT = $FontPath
    $env:JG2_V26_PACKET = $PacketCopy
    $env:JG2_V26_QA_DUMP = $null
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building shared dates and daily narration across 78 text banks..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_shared_dates_v26 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v26 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "shared-dates-v26-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-shared-dates-v26.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.runtime_images -ne 78 -or $Report.source_patterns -ne 46 -or $Report.source_date_coordinates -ne 4836 -or ($Report.translated_coordinates + $Report.custom_coordinates_preserved) -ne 4836 -or -not $Report.all_other_payloads_and_non_text_records_preserved -or $Report.packet_sha256 -ne $ExpectedPacketHash) { throw "Final report scope verification failed." }
if ((Get-Item -LiteralPath $OutputBin).Length -ne $ExpectedDiscBytes -or (Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output length/hash differs from the build report." }
if ((Hash $PacketCopy) -ne $ExpectedPacketHash) { throw "Candidate translation input changed during build." }
if ((Hash $FontPath) -ne $OriginalFontHash -or $Report.font_sha256 -ne $OriginalFontHash) { throw "Font identity changed during the build." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "SHARED DATES AND DAILY NARRATION ENGLISH v26 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host ("Changed raw sectors: " + $Report.changed_sector_count)
Write-Host ("Translated date/narration coordinates: " + $Report.translated_coordinates)
Write-Host ("Custom existing payloads retained: " + $Report.custom_coordinates_preserved)
Write-Host "Reviewed source scope: 46 date/narration patterns across 78 School Life text banks."
Write-Host ("Native glyph previews: " + (Join-Path $BuildDir "previews"))
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v25. Boot this new CUE fresh, load your in-game save, and check April 21 daily narration."
Write-Host "Also check one seasonal/exam notice and an earlier translated event. Unique story dialogue remains outside this shared-text batch."

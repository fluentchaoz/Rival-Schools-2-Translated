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
        $Folders = @(Get-ChildItem -LiteralPath $CandidateRoot -Directory -Filter "rating-popup-v20-*" | Sort-Object LastWriteTimeUtc -Descending)
        foreach ($Folder in $Folders) {
            $Candidate = Join-Path $Folder.FullName "build/justice-gakuen2-rating-popup-v20.bin"
            if ((Test-Path -LiteralPath $Candidate -PathType Leaf) -and (Hash $Candidate) -eq "bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec") {
                $MasterBin = $Candidate
                break
            }
        }
    }
    if (-not $MasterBin) { throw "No verified v20 candidate found. Pass -MasterBin with the v20 BIN from your successful build." }
}
if (-not $FontPath) { $FontPath = "C:\Windows\Fonts\arial.ttf" }
$FontPath = FullPath $FontPath
if (-not $WorkRoot) { $WorkRoot = Join-Path $RecoveryRoot ("candidates/entrance-ceremony-v21-" + [Guid]::NewGuid().ToString("N")) }
$SourceBin = FullPath $SourceBin
$MasterBin = FullPath $MasterBin
$WorkRoot = FullPath $WorkRoot
$RustPath = Join-Path $UpstreamRoot "src/dialogue_audit/name_entry_input_tests.rs"
$ExpectedMasterHash = "bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec"
$ExpectedSourceHash = "0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e"
$ExpectedDiscBytes = [long]663216960
$BuildDir = Join-Path $WorkRoot "build"
$Backup = Join-Path $WorkRoot "name_entry_input_tests.pre-v21.rs.bak"
$LogPath = Join-Path $WorkRoot "build-v21.log"
Write-Host "Justice Gakuen English Project - ENTRANCE CEREMONY ENGLISH v21" -ForegroundColor Cyan
foreach ($Path in @($RustPath,$SourceBin,$MasterBin,$FontPath,(Join-Path $UpstreamRoot "Cargo.toml"))) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing required file: $Path" }
}
if ((Hash $MasterBin) -ne $ExpectedMasterHash) { throw "v20 master hash mismatch. No files changed." }
if ((Hash $SourceBin) -ne $ExpectedSourceHash) { throw "Original source hash mismatch. No files changed." }
foreach ($Path in @($MasterBin,$SourceBin)) {
    if ((Get-Item -LiteralPath $Path).Length -ne $ExpectedDiscBytes) { throw "Disc length mismatch: $Path" }
}
if (Test-Path -LiteralPath $WorkRoot) { throw "Output already exists: $WorkRoot. Use a new -WorkRoot; existing work is never replaced." }
if ($null -eq (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "Cargo is not on PATH. Use the terminal where recovery succeeded." }
$OriginalFontHash = Hash $FontPath
$OriginalRust = [IO.File]::ReadAllBytes($RustPath)
$OriginalRustHash = Hash $RustPath
if ([IO.File]::ReadAllText($RustPath).Contains("ENGLISH_PROJECT_ENTRANCE_CEREMONY_V21")) {
    throw "A previous v21 source injection remains. Restore name_entry_input_tests.pre-v21.rs.bak from that run's candidate folder before retrying."
}
$TargetPath = if ($env:CARGO_TARGET_DIR) { FullPath $env:CARGO_TARGET_DIR } else { Join-Path $UpstreamRoot "target" }
Assert-FreeSpace $WorkRoot $ExpectedDiscBytes $TargetPath
Write-Host ("v20 input: " + $MasterBin)
Write-Host "Verified original and v20 images, font, source availability, output ownership, and free space." -ForegroundColor Green
if ($CheckOnly) { Write-Host "Preflight passed. No files changed." -ForegroundColor Green; return }
$Rust = @'
// ENGLISH_PROJECT_ENTRANCE_CEREMONY_V21
mod english_ceremony_v21 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde_json::{json,Value};
 use super::super::{atlas,parser,tokens};
 use crate::{pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild,tim::{Cell,read_8bpp_indexed_cell_in_prefix,read_8bpp_palette_words_in_prefix,write_8bpp_indexed_cell_in_prefix}};
 const MASTER_HASH:&str="bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const DIALOGUE:&str="DAT2/MGG04T.BIZ";
 const BUNDLE:&str="DAT2/MGG04.BZZ";
 const GRAPHICS:&str="DAT2/MGBGG04.BZZ";
 const DH:&str="61ec57bdb4e7df253f46bb7c5c053abe866e38b033311c06b01c36f950c440d3";
 const BH:&str="ddb5ac288e979a27e3f23f09b65601739f5ad8c1cd09806ed9731c8dabbb4e3c";
 const GH:&str="7fe06a64a164abd70fe71d0ddf2e6e93ff43b6accd0ffd779f1f61128d5e3ebc";
 const PACKET:&str=r###"{
  "record": "DAT2/MGG04T.BIZ",
  "selectors": [
    0,
    1
  ],
  "first_entry": 0,
  "entries": [
    "TAIYO'S ENTRANCE\nCEREMONY IS TODAY.\nI'M EARLY. CAN'T BE\nLATE ON DAY ONE!",
    "IT FEELS GOOD TO BE\nUP EARLY. OH,\nTHERE'S BATSU. WHY'S\nHE IN SUCH A HURRY?",
    "HEY, BATSU! WHAT'S\nTHE RUSH?",
    "QUIT DAYDREAMING,\n{NAME}!\nHURRY OR WE'LL\nBE LATE!",
    "HUH?! BATSU, WHAT\nARE YOU SAYING?\nWE'VE STILL GOT AN\nHOUR!",
    "WHAT?! WE'RE ALMOST\nLATE! LOOK... HUH? I\nMISREAD MY WATCH BY\nAN HOUR...",
    "YOU'RE HERE AWFULLY\nEARLY FOR ONCE,\nBATSU.",
    "OH, MORNING,\nKYOSUKE.",
    "UGH. OF ALL PEOPLE,\nHE HAD TO CATCH\nME...",
    "HM? SOUNDS AMUSING.\nWHAT HAPPENED?",
    "WELL, KYOSUKE, BATSU\nLOOKED AT HIS WATCH\nAND...",
    "HEH. MAKING US LAUGH\nALREADY, BATSU? AND\nTHE CEREMONY HASN'T\nEVEN STARTED.",
    "HAHA! WHO MAKES A\nMISTAKE LIKE THAT\nTHESE DAYS?",
    "...TCH.",
    "I'M LATE, I'M LATE!\nHEY, WHAT ARE YOU\nALL DOING HERE? COME\nON, HURRY!",
    "...PFFT.",
    "HAHAHA! HINATA, YOU\nTOO?!",
    "HEH HEH. THAT'S OUR\nHINATA...",
    "W-WHAT? WHY ARE YOU\nLAUGHING? WE'RE\nGOING TO BE LATE!",
    "HAHAHAHA...",
    "WELL, THAT WAS QUITE\nA COMMOTION BEFORE\nTHE CEREMONY...",
    "HEH, REALLY. MAKING\nTHE SAME MISTAKE...\nYOU TWO GET ALONG SO\nWELL.",
    "STILL LAUGHING? I\nWAS JUST IN A RUSH.\nDON'T LUMP ME IN\nWITH BATSU!",
    "I'M JUST AS SHOCKED!\nANYWAY, THE SPEECH\nIS SO LONG...",
    "YEAH... IT'S BORING.\nI WISH I COULD SNEAK\nOUT...",
    "BATSU, YOU SHOULDN'T\nKEEP SAYING THINGS\nLIKE THAT.",
    "YOU THERE! QUIET!\nTHE ENTRANCE\nCEREMONY IS STILL\nGOING ON!",
    "(OH, CLASS REP. SHE\nREALLY IS\nSERIOUS...)",
    "APOLOGIZE\nTEASE HER",
    "SORRY, CLASS REP...\nWE'LL BE QUIET...",
    "..........",
    "...BUT HOW ARE YOU\nCLASS REP ALREADY?\nWE'VE ONLY JUST\nSTARTED SCHOOL.",
    "...OH? I'M ALREADY\nON THE DISCIPLINARY\nCOMMITTEE, YOU KNOW.",
    "...HUH? ISN'T THAT A\nBIT ODD?",
    "YOU THERE! BE QUIET!\nHOW LONG DO YOU PLAN\nTO KEEP CHATTING?!",
    "(YIKES... NOW WE'RE\nREALLY IN\nTROUBLE...)",
    "CLICK!",
    "(HUH? I THOUGHT I\nSAW A FLASH... MAYBE\nIT WAS NOTHING?)",
    "(LET'S TEASE HER...)\nCLASS REP'S FIRED UP\nALREADY! RIGHT,\nBATSU?",
    "YEAH. BUT SHE'S\nSCARY WHEN SHE'S\nMAD. WATCH YOURSELF.",
    "WHAT DID YOU SAY?!",
    "YOU THERE! STILL\nTALKING?! BE QUIET!",
    "(YIKES... WE GOT\nTOLD OFF. I FEEL BAD\nFOR CLASS REP...)",
    "CLICK!",
    "(HUH? I THOUGHT I\nSAW A FLASH... MAYBE\nIT WAS NOTHING?)",
    "GETTING TOLD OFF AT\nTHE ENTRANCE\nCEREMONY... WHAT A\nSTART.",
    "(HUH? WHO'S THAT\nWITH A CAMERA? SHE'S\nTAKING LOTS OF\nPICTURES.)",
    "HEY. WHAT ARE YOU\nDOING OVER THERE?",
    "ME? TAKING PICTURES,\nOBVIOUSLY! IT'S FOR\nTHE NEWSPAPER CLUB'S\nENTRANCE TEST...",
    "OH, YOU'RE THE ONE\nWHO GOT TOLD OFF! I\nGOT A GREAT SHOT OF\nYOU!",
    "OH... SO THAT FLASH\nWAS...",
    "YEP, ME! I WANT TO\nJOIN THE NEWSPAPER\nCLUB, BUT THEY HAVE\nAN ENTRANCE TEST.",
    "THE TEST IS TO GET A\nSCOOP AT THE\nCEREMONY. THANKS FOR\nTHE GREAT PHOTO!",
    "YOU'RE A FIRST-YEAR\nTOO? WAIT... DIDN'T\nYOU GO TO THE\nCEREMONY?",
    "HEH, NEVER MIND! I'M\nRAN, A FUTURE\nREPORTER. NICE TO\nMEET YOU!",
    "THE CEREMONY'S OVER\nAT LAST. NOW I NEED\nTO JOIN A CLUB.",
    "THE ALL-SCHOOL CLUB\nORIENTATION IS IN\nTHE CLUB BUILDING.\nWHERE IS THAT?"
  ]
}
"###;
 fn words(b:&[u8])->Vec<u16>{b.chunks_exact(2).map(|p|u16::from_le_bytes([p[0],p[1]])).collect()}
 fn bytes(mut w:Vec<u16>)->Vec<u8>{if w.len()%2!=0{w.push(0);}w.into_iter().flat_map(u16::to_le_bytes).collect()}
 // Line breaks and blank-column padding are English layout choices. Preserve
 // all semantic insertions, renderer modes, styles, and message terminators.
 fn controls(b:&[u8],fixed:usize,slots:usize)->Result<Vec<(u16,Vec<u16>)>>{
  Ok(tokens::tokenize_dialogue_message(&words(b),fixed,slots)?.tokens.into_iter().filter(|t|!matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph|tokens::DialogueTokenKind::LineBreak|tokens::DialogueTokenKind::SkippedCode)).map(|t|(t.code,t.arguments)).collect())
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
 fn text_record(source:&[u8],font:&fontdue::Font)->Result<(Vec<u8>,Vec<u8>,Value)>{
  ensure!(sha256_bytes(source)==DH,"Taiyo source identity changed");let before=decompress(source,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let banks=parser::parse_dialogue_banks(&before)?;
  ensure!(banks[0].messages.len()==563 && banks[1].messages.len()==563,"Taiyo dialogue population changed");
  let packet:Value=serde_json::from_str(PACKET)?;let entries=packet["entries"].as_array().context("missing entries")?;ensure!(entries.len()==57,"translation packet shape");
  let mut chars=BTreeSet::from([' ','/']);
  for entry in entries{for c in entry.as_str().context("entry")?.replace("{NAME}","").chars(){if c!='\n'{ensure!(c.is_ascii(),"non ASCII target");chars.insert(c);}}}
  let mut used=BTreeSet::new();
  for b in &banks{for m in &b.messages{for t in tokens::tokenize_dialogue_message(&words(&m.data),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){used.insert(t.code as usize);}}}}
  let mut first=at.fixed_cell_count;
  for i in 0..at.addressable_slot_count {if used.contains(&i)||before[at.pixel_data_offset+i*200..at.pixel_data_offset+(i+1)*200].iter().any(|b|*b!=0){first=first.max(i+1);}}
  ensure!(first+chars.len()<=at.addressable_slot_count,"insufficient unused glyph slots");let mut after=before.clone();let mut codes=BTreeMap::new();
  for (n,c) in chars.iter().enumerate(){let code=first+n;codes.insert(*c,code as u16);let(w,h,pts)=ink(font,&c.to_string(),14.0)?;ensure!(w<=18&&h<=18,"ASCII glyph too large");let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;
   for &(x,y) in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}
   for (x,y) in pts{pix[(y+dy)*20+x+dx]=14;}let p=at.pixel_data_offset+code*200;ensure!(after[p..p+200].iter().all(|x|*x==0),"glyph slot occupied");for(i,pair)in pix.chunks_exact(2).enumerate(){after[p+i]=pair[0]|pair[1]<<4;}
  }
  let mut replacements=BTreeMap::new();
  for sel in [0usize,1]{for (i,e) in entries.iter().enumerate(){let text=e.as_str().unwrap();let mut w=Vec::new();let mut lines=0;
   if i==30{w.extend([0x3002,15]);}
   for (li,line) in text.split('\n').enumerate(){lines+=1;if li>0{w.push(0x3000);}let visible=line.replace("{NAME}","XXXXXX").len();ensure!(visible<=20,"entry {i} line too wide");let mut rest=line;
    while let Some(pos)=rest.find("{NAME}"){for c in rest[..pos].chars(){w.push(codes[&c]);}w.extend([0x2003,0]);rest=&rest[pos+6..];}for c in rest.chars(){w.push(codes[&c]);}
   }
   ensure!(lines<=4,"entry {i} too many lines");if i==28{ensure!(lines==2,"choice row count changed");}if i==30{w.extend([0x3002,255]);}w.push(0x3001);let data=bytes(w);
   ensure!(controls(&data,at.fixed_cell_count,at.addressable_slot_count)?==controls(&banks[sel].messages[i].data,at.fixed_cell_count,at.addressable_slot_count)?,"protected controls changed s{sel} e{i}");replacements.insert((sel,i),data);
  }}
  for sel in [3usize,4]{for i in [18usize,19]{let old=&banks.iter().find(|b|b.selector_index==sel).context("date bank")?.messages[i].data;
   ensure!(words(old)==vec![0x3003,1,0x200a,0x187,0x200b,0x12a,0x3003,255,0x3001,0],"date template changed");let new=bytes(vec![0x3003,1,0x200a,codes[&'/'],0x200b,0x3003,255,0x3001]);ensure!(controls(old,at.fixed_cell_count,at.addressable_slot_count)?==controls(&new,at.fixed_cell_count,at.addressable_slot_count)?,"date controls changed");replacements.insert((sel,i),new);
  }}
  after[0x31000..0x4a000].fill(0);let mut cursor=0x31020;let mut expected=Vec::new();
  for b in &banks{let mut ptrs=Vec::new();let mut messages=Vec::new();for(i,m)in b.messages.iter().enumerate(){let d=replacements.get(&(b.selector_index,i)).unwrap_or(&m.data);ensure!(cursor%4==0&&d.len()%4==0&&cursor+d.len()<=0x4a000,"arena overflow");ptrs.push(cursor);after[cursor..cursor+d.len()].copy_from_slice(d);cursor+=d.len();messages.push(d.clone());}
   let table=cursor;for p in ptrs{ensure!(cursor+4<=0x4a000,"pointer overflow");after[cursor..cursor+4].copy_from_slice(&(0x800d0000+p as u32).to_le_bytes());cursor+=4;}ensure!(cursor+4<=0x4a000,"table overflow");after[cursor..cursor+4].copy_from_slice(&u32::MAX.to_le_bytes());cursor+=4;after[0x31000+b.selector_index*4..0x31004+b.selector_index*4].copy_from_slice(&(0x800d0000+table as u32).to_le_bytes());expected.push(messages);
  }
  for((b,old),wanted)in parser::parse_dialogue_banks(&after)?.iter().zip(&banks).zip(expected){ensure!(b.selector_index==old.selector_index&&b.messages.len()==old.messages.len(),"bank shape changed");for(i,(m,w))in b.messages.iter().zip(wanted).enumerate(){ensure!(m.data==w,"parseback failed");if !replacements.contains_key(&(b.selector_index,i)){ensure!(m.data==old.messages[i].data,"untranslated message changed");}}}
  let lo=at.pixel_data_offset+first*200;let hi=lo+chars.len()*200;ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(lo..hi).contains(&i)||(0x31000..0x4a000).contains(&i)),"change escaped font/messages");
  let profile=crate::paged_compression::source_paged_compression_profile(source)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,source.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"dialogue roundtrip");stored.resize(source.len(),0);ensure!(decompress(&stored,true)?==after,"padded dialogue roundtrip");
  let report=json!({"translated_dialogue_entries":114,"translated_date_entries":4,"glyph_start":first,"glyph_count":chars.len(),"glyph_codes":codes,"compressed_bytes":length,"fixed_slot":source.len(),"arena_used":cursor-0x31020,"arena_capacity":0x4a000-0x31020,"source_sha256":DH,"patched_sha256":sha256_bytes(&stored),"script_unchanged":true,"other_messages_unchanged":true,"protected_controls_preserved":true});Ok((stored,after,report))
 }
 fn color(pal:&[u16],rgb:[i32;3])->u8{(0..pal.len()).min_by_key(|&i|[0,5,10].iter().enumerate().map(|(c,s)|(((pal[i]>>s)&31)as i32*255/31-rgb[c]).pow(2)).sum::<i32>()).unwrap() as u8}
 fn put_text(pix:&mut[u8],width:usize,cell:Cell,text:&str,size:f32,font:&fontdue::Font,pal:&[u16],rainbow:bool)->Result<()>{
  let(w,raw_h,raw_pts)=ink(font,text,size)?;let scale=if rainbow{2}else{1};let h=raw_h*scale;let pts=raw_pts.into_iter().flat_map(|(x,y)|(0..scale).map(move|dy|(x,y*scale+dy))).collect::<Vec<_>>();ensure!(w+2<=cell.width&&h+2<=cell.height,"{text} does not fit");let dx=cell.x+(cell.width-w)/2;let dy=cell.y+(cell.height-h)/2;let outline=color(pal,[25,20,25]);let white=color(pal,[255,255,255]);
  for &(x,y) in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{pix[yy*width+xx]=outline;}}}
  for(x,y)in pts{let rgb=if x*4/w.max(1)==0{[230,80,255]}else if x*4/w.max(1)==1{[40,170,255]}else if x*4/w.max(1)==2{[80,255,70]}else{[255,200,40]};pix[(y+dy)*width+x+dx]=if rainbow{color(pal,rgb)}else{white};}Ok(())
 }
 fn png(path:&Path,pix:&[u8],w:usize,h:usize,pal:&[u16])->Result<()>{let mut rgb=Vec::new();for &i in pix{let p=pal[i as usize];for s in [0,5,10]{rgb.push((((p>>s)&31)*255/31)as u8);}}let mut e=png::Encoder::new(BufWriter::new(fs::File::create(path)?),w as u32,h as u32);e.set_color(png::ColorType::Rgb);e.set_depth(png::BitDepth::Eight);e.write_header()?.write_image_data(&rgb)?;Ok(())}
 fn patched_tim(source:&[u8],kind:usize,font:&fontdue::Font,out:&Path)->Result<Vec<u8>>{
  let mut after=source.to_vec();let pal=read_8bpp_palette_words_in_prefix(source,0,0)?;
  if kind==0{ensure!(source.len()==56864,"title TIM size");let all=read_8bpp_indexed_cell_in_prefix(source,0,Cell{x:0,y:0,width:256,height:220})?;let mut p=vec![0u8;512*110];for y in 0..110{for x in 0..512{p[y*512+x]=all[(y+(x/256)*110)*256+x%256];}}
   let regions=[Cell{x:175,y:16,width:160,height:30},Cell{x:149,y:55,width:214,height:40}];
   for c in regions{for y in c.y..c.y+c.height{let mut counts=[0usize;256];for x in 0..512{if x<c.x||x>=c.x+c.width{counts[p[y*512+x]as usize]+=1;}}let bg=(0..256).max_by_key(|i|counts[*i]).unwrap()as u8;for x in c.x..c.x+c.width{p[y*512+x]=bg;}}}
   put_text(&mut p,512,regions[0],"APRIL 8",18.0,font,&pal,true)?;put_text(&mut p,512,regions[1],"ENTRANCE CEREMONY",18.0,font,&pal,true)?;
   png(&out.join("entrance-title-v21.png"),&p,512,110,&pal)?;let mut native=all;for y in 0..110{for x in 0..512{native[(y+(x/256)*110)*256+x%256]=p[y*512+x];}}
   write_8bpp_indexed_cell_in_prefix(&mut after,0,Cell{x:0,y:0,width:256,height:220},&native)?;
   for y in 0..110{for x in 0..512{let i=(y+(x/256)*110)*256+x%256;ensure!(source[544+i]==after[544+i]||regions.iter().any(|r|x>=r.x&&x<r.x+r.width&&y>=r.y&&y<r.y+r.height),"title change outside text areas");}}
  }else{let label=Cell{x:0,y:220,width:128,height:24};let text=if kind==1{"SCHOOL GATE"}else{"GYM"};let mut p=vec![0u8;128*24];let mut ok=false;for size in [12.0,11.0,10.0,9.0]{if put_text(&mut p,128,Cell{x:2,y:1,width:78,height:22},text,size,font,&pal,false).is_ok(){ok=true;break;}}ensure!(ok,"location label does not fit");let allowed=write_8bpp_indexed_cell_in_prefix(&mut after,0,label,&p)?;ensure!(source.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||allowed.iter().any(|r|i>=r[0]&&i<r[1])),"label ownership");png(&out.join(format!("location-{kind}-v21.png")),&p,128,24,&pal)?;}
  ensure!(source[..544]==after[..544],"palette/header changed");Ok(after)
 }
 fn graphics(source:&[u8],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  ensure!(sha256_bytes(source)==GH,"graphics identity changed");let slots=crate::tzz::parse_tzz(source)?;let zero=decompress(&source[slots[0].compressed_range()],false)?;let one=decompress(&source[slots[1].compressed_range()],false)?;
  let tims=[zero[..56864].to_vec(),zero[0x1c000..0x1c000+63008].to_vec(),one[..63008].to_vec()];ensure!(sha256_bytes(&tims[0])=="0d5c4079085f11e1b158817650eeef021f234e64879df5bbd59dc2aeefc97f29","title identity");
  let mut patched=Vec::new();for(i,t)in tims.iter().enumerate(){patched.push(patched_tim(t,i,font,out)?);}
  let mut archive=source.to_vec();let mut report=Vec::new();let mut counts=[0usize;3];
  for slot in &slots{let stored=&source[slot.compressed_range()];let before=decompress(stored,false)?;let mut after=before.clone();let mut ranges=Vec::new();
   for(kind,t)in tims.iter().enumerate(){for off in (0..=before.len().saturating_sub(t.len())).step_by(4){if before.get(off..off+t.len())==Some(t.as_slice()){after[off..off+t.len()].copy_from_slice(&patched[kind]);ranges.push(off..off+t.len());counts[kind]+=1;}}}
   if after==before{continue;}ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|r.contains(&i))),"graphics member ownership");
   let profile=crate::paged_compression::source_paged_compression_profile(stored)?;let prefix=before.iter().zip(&after).take_while(|(a,b)|a==b).count()&!1;
   let(encoded,kept)=crate::paged_compression::compress_on_source_final_page_with_preserved_prefix(&after,stored,profile,prefix)?;let new=crate::paged_compression::source_paged_compression_profile(&encoded)?;
   ensure!((new.stream_byte_count-1)/0x800==(profile.stream_byte_count-1)/0x800&&new.maximum_match_words<=profile.maximum_match_words&&new.maximum_control_block_output_words<=profile.maximum_control_block_output_words&&kept.encoded_byte_count>0,"native compression contract");
   ensure!(encoded.len()<=slot.compressed_size,"graphics member {} exceeds slot",slot.index);ensure!(decompress(&encoded,false)?==after,"graphics roundtrip");let length=encoded.len();let mut padded=encoded;padded.resize(slot.compressed_size,0);ensure!(decompress(&padded,true)?==after,"padded graphics roundtrip");archive[slot.compressed_range()].copy_from_slice(&padded);report.push(json!({"member":slot.index,"compressed_bytes":length,"fixed_slot":slot.compressed_size}));
  }
  ensure!(counts[0]==5&&counts[1]==6&&counts[2]==3,"ceremony copy population changed");ensure!(crate::tzz::parse_tzz(&archive)?==slots,"graphics table changed");Ok((archive,json!({"copies":counts,"members":report,"palettes_preserved":true,"other_tim_images_preserved":true})))
 }
 fn run(master:Option<&Path>)->Result<()> {
  let source=PathBuf::from(std::env::var("JG2_V21_SOURCE")?);ensure!(sha256_file(&source)?==SOURCE_HASH,"source disc mismatch");if let Some(m)=master{ensure!(sha256_file(m)?==MASTER_HASH,"v20 master mismatch");}
  let font_bytes=fs::read(std::env::var("JG2_V21_FONT")?)?;let font=fontdue::Font::from_bytes(font_bytes.clone(),fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  let out=PathBuf::from(std::env::var("JG2_V21_OUTPUT")?);ensure!(!out.exists(),"output exists");fs::create_dir_all(&out)?;
  let mut originals=Vec::new();for(path,hash)in [(DIALOGUE,DH),(BUNDLE,BH),(GRAPHICS,GH)]{let data=rebuild::read_record(&source,path)?.1;ensure!(sha256_bytes(&data)==hash,"source {path} identity");if let Some(m)=master{ensure!(rebuild::read_record(m,path)?.1==data,"v20 already changed {path}");}originals.push(data);}
  let(text,decoded,text_report)=text_record(&originals[0],&font)?;let mut bundle=originals[1].clone();let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5&&&bundle[slots[0].compressed_range()]==originals[0].as_slice(),"Taiyo bundle binding changed");bundle[slots[0].compressed_range()].copy_from_slice(&text);ensure!(bundle[..slots[0].offset]==originals[1][..slots[0].offset]&&bundle[slots[0].offset+slots[0].compressed_size..]==originals[1][slots[0].offset+slots[0].compressed_size..],"other schools changed");
  let(graphic,graphic_report)=graphics(&originals[2],&font,&out)?;let mut report=json!({"kind":"Taiyo entrance ceremony English v21","text":text_report,"graphics":graphic_report,"font_sha256":sha256_bytes(&font_bytes),"earlier_layers_preserved":true,"other_schools_dialogue_preserved":true,"source_sha256":SOURCE_HASH,"master_sha256":MASTER_HASH});
  if let Some(m)=master{let bin=out.join("justice-gakuen2-entrance-ceremony-v21.bin");let repl=[rebuild::FixedRecordReplacement{path:DIALOGUE,data:&text},rebuild::FixedRecordReplacement{path:BUNDLE,data:&bundle},rebuild::FixedRecordReplacement{path:GRAPHICS,data:&graphic}];let rebuilt=rebuild::copy_and_replace_records(m,&bin,&repl)?;
   for r in &repl{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback");}let allowed=rebuilt.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(m,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|i|allowed.contains(i)),"sector scope failed");let mut track=crate::disc::RawTrack::open(&bin)?;for lba in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*lba)?),"sector checksum");}
   ensure!(sha256_file(m)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"input changed");let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-entrance-ceremony-v21.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;report["output_sha256"]=json!(hash);report["changed_sector_count"]=json!(changed.len());report["cue"]=json!(cue.display().to_string());eprintln!("ENTRANCE_CEREMONY_V21_COMPLETE=1\nOUTPUT_SHA256={hash}\nCHANGED_RAW_SECTORS={}\nCUE={}",changed.len(),cue.display());
  }else{fs::write(out.join("MGG04T.BIZ"),&text)?;fs::write(out.join("MGG04T.decoded"),decoded)?;fs::write(out.join("MGG04.BZZ"),bundle)?;fs::write(out.join("MGBGG04.BZZ"),graphic)?;}
  fs::write(out.join("entrance-ceremony-v21-report.json"),serde_json::to_vec_pretty(&report)?)?;eprintln!("{}",serde_json::to_string_pretty(&report)?);Ok(())
 }
 #[test] fn english_project_entrance_ceremony_v21()->Result<()>{let p=PathBuf::from(std::env::var("JG2_V21_MASTER")?);std::thread::Builder::new().stack_size(64*1024*1024).spawn(move||run(Some(&p)))?.join().unwrap()}
 #[test] #[ignore="private source disc and local font"] fn entrance_ceremony_v21_records()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(||run(None))?.join().unwrap()}
}

'@
$SavedEnvironment = @{}
foreach ($Name in @("CARGO_HOME","CARGO_TARGET_DIR","RUSTUP_TOOLCHAIN","JG2_V21_MASTER","JG2_V21_SOURCE","JG2_V21_OUTPUT","JG2_V21_FONT")) {
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
    $env:JG2_V21_MASTER = $MasterBin
    $env:JG2_V21_SOURCE = $SourceBin
    $env:JG2_V21_OUTPUT = $BuildDir
    $env:JG2_V21_FONT = $FontPath
    [IO.File]::WriteAllBytes($RustPath,$Injected)
    Write-Host "Building the Taiyo entrance ceremony and verifying the candidate..." -ForegroundColor Cyan
    Push-Location $UpstreamRoot
    try {
        $SavedPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & cargo test --locked --lib english_project_entrance_ceremony_v21 -- --nocapture 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
            $CargoExit = $LASTEXITCODE
        } finally { $ErrorActionPreference = $SavedPreference }
        if ($CargoExit -ne 0) { throw "v21 build failed with exit code $CargoExit. Keep $LogPath for diagnosis." }
    } finally { Pop-Location }
} finally {
    try {
        [IO.File]::WriteAllBytes($RustPath,$OriginalRust)
        if ((Hash $RustPath) -ne $OriginalRustHash) { throw "Source restoration failed. The exact backup is $Backup" }
    } finally {
        foreach ($Name in $SavedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($Name,$SavedEnvironment[$Name],"Process") }
    }
}
$ReportPath = Join-Path $BuildDir "entrance-ceremony-v21-report.json"
$OutputBin = Join-Path $BuildDir "justice-gakuen2-entrance-ceremony-v21.bin"
$OutputCue = [IO.Path]::ChangeExtension($OutputBin,".cue")
$Preview = Join-Path $BuildDir "entrance-title-v21.png"
foreach ($Path in @($ReportPath,$OutputBin,$OutputCue,$Preview)) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Build did not produce required output: $Path" }
}
$Report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
if ($Report.text.translated_dialogue_entries -ne 114 -or $Report.text.translated_date_entries -ne 4 -or -not $Report.earlier_layers_preserved -or -not $Report.other_schools_dialogue_preserved) { throw "Final report scope verification failed." }
if ((Get-Item -LiteralPath $OutputBin).Length -ne $ExpectedDiscBytes -or (Hash $OutputBin) -ne $Report.output_sha256) { throw "Final output length/hash differs from the build report." }
if ((Hash $FontPath) -ne $OriginalFontHash -or $Report.font_sha256 -ne $OriginalFontHash) { throw "Font identity changed during the build." }
if ((Hash $MasterBin) -ne $ExpectedMasterHash -or (Hash $SourceBin) -ne $ExpectedSourceHash) { throw "An input image changed during the build." }
Write-Host ""
Write-Host "ENTRANCE CEREMONY ENGLISH v21 CANDIDATE BUILT" -ForegroundColor Green
Write-Host ("Output BIN SHA-256: " + $Report.output_sha256)
Write-Host ("Changed raw sectors: " + $Report.changed_sector_count)
Write-Host ("Dialogue compressed bytes: {0} / {1}" -f $Report.text.compressed_bytes,$Report.text.fixed_slot)
Write-Host "114 dialogue entries + 4 dynamic date messages translated. Both player variants and both ceremony choices covered."
Write-Host "APRIL 8 / ENTRANCE CEREMONY, SCHOOL GATE, and GYM graphics installed."
Write-Host "Earlier quiz, enrollment, classroom and stat layers preserved."
Write-Host ""
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("TITLE PREVIEW: " + $Preview)
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v20. Boot the new CUE fresh, complete the quiz, then check the full Taiyo entrance ceremony and both choices."
Write-Host "The following club-orientation events and other schools' ceremony dialogue remain untranslated."

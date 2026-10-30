// ENGLISH_PROJECT_STATUS_DIARY_V28
mod english_status_diary_v28 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde::Deserialize;
 use serde_json::{json,Value};
 use super::super::{atlas,tokens};
 use crate::{tim::{Cell,read_indexed_cell_in_prefix,write_indexed_cell_in_prefix,read_4bpp_palette_words_in_prefix},pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild};
 const MASTER_HASH:&str="3f5b7630fd3115804c892e75c37213fbfff148b28ed657d0424ecba0614dc34e";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const PACKET_HASH:&str="1ab4acbf72a23100756e6e1a689169b01da7448032aa0bad8a0a4da81f99e3b7";
 const ARENA:usize=0x31000;
 const LIMIT:usize=0x4a000;
 type Banks=Vec<(usize,Vec<Vec<u8>>)>;
 #[derive(Deserialize)] struct Packet {source_sha256:String,source_pattern_count:usize,source_coordinate_count:usize,runtime_images:usize,entries:Vec<Entry>,labels:Vec<Label>}
 #[derive(Deserialize)] struct Label {id:String,text:String,cell:[usize;4],palette:usize}
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
  for((sel,ms),(_,sms))in old.iter().zip(&src){for(i,(m,sm))in ms.iter().zip(sms).enumerate(){if *sel!=2||!(113..=169).contains(&i){continue;}let st=fingerprint_tokens(&source,sm,&sat)?;source_count+=1;
   let fp=sha256_bytes(&serde_json::to_vec(&st)?);let entry=entries.get(&fp).context("unreviewed source help pattern")?;*seen.entry(fp.clone()).or_default()+=1;
   ensure!(controls(sm,sat.fixed_cell_count,sat.addressable_slot_count)?.into_iter().filter(|(c,_)|*c!=0x3001).collect::<Vec<_>>()==entry.protected_controls,"packet protected controls differ");
   let ct=fingerprint_tokens(&before,m,&at)?;if ct!=st{preserved.push(json!({"selector":sel,"entry":i,"reason":"current custom payload retained byte-for-byte","sha256":sha256_bytes(m)}));continue;}
   targets.insert((*sel,i),fp);
  }}ensure!(source_count==57,"source help population for {path}");
  if targets.is_empty(){return Ok((current.to_vec(),json!({"path":path,"source_messages":source_count,"translated":0,"preserved_custom":preserved})));}
  let mut chars=BTreeSet::new();for fp in targets.values(){chars_of(&entries[fp].fitted_text,&mut chars)?;}chars.extend(['M','D']);let mut after=before.clone();let(codes,allocated)=install_glyphs(&before,&mut after,&old,&at,&chars,font)?;let mut wanted=old.clone();
  for((sel,ms),(_,prior))in wanted.iter_mut().zip(&old){for(i,m)in ms.iter_mut().enumerate(){if let Some(fp)=targets.get(&(*sel,i)){*m=encode_target(&entries[fp].fitted_text,&prior[i],&codes,&at).with_context(||format!("{path} selector {sel} entry {i}"))?;}}}
  let(used,aliases)=compact(&mut after,&wanted)?;let read=pointer_banks(&after)?;ensure!(read==wanted,"pointer readback");
  for((sel,ms),(_,prior))in read.iter().zip(&old){for(i,m)in ms.iter().enumerate(){tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;if !targets.contains_key(&(*sel,i)){ensure!(m==&prior[i],"untargeted payload changed");}}}
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(ARENA..LIMIT).contains(&i)||allocated.iter().any(|g|(at.pixel_data_offset+g*200..at.pixel_data_offset+(g+1)*200).contains(&i))),"change outside arena/new empty glyph cells");
  let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len()).with_context(||format!("fixed compressed slot {path}"))?;let length=stored.len();stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"compressed readback");
  for(&(sel,i),fp)in &targets{if previews.insert(fp.clone()){let m=&read.iter().find(|(s,_)|*s==sel).context("preview selector")?.1[i];preview(&out.join("previews").join(format!("{}.png",entries[fp].id)),&after,m,&at,&codes)?;}}
  if std::env::var_os("JG2_V28_QA_DUMP").is_some(){fs::write(out.join(format!("{}.decoded",Path::new(path).file_stem().unwrap().to_string_lossy())),&after)?;}
  Ok((stored,json!({"path":path,"source_messages":source_count,"translated":targets.len(),"preserved_custom":preserved,"new_glyphs":allocated.len(),"glyph_codes":codes,"arena_used":used,"arena_capacity":LIMIT-ARENA-32,"aliases":aliases,"compressed_bytes":length,"fixed_slot":current.len(),"untargeted_payloads_fonts_and_scripts_preserved":true})))
 }
 fn canvas(font:&fontdue::Font,text:&str,width:usize,height:usize,fill:u8,outline:u8)->Result<Vec<u8>>{
  for size in [22.0f32,21.0,20.0,19.0,18.0,17.0,16.0,15.0,14.0,13.0,12.0,11.0,10.0,9.0]{let(w,h,pts)=ink(font,text,size)?;if w+2>width||h+2>height{continue;}let dx=(width-w)/2;let dy=(height-h)/2;let mut pix=vec![0u8;width*height];for &(x,y)in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{pix[yy*width+xx]=outline;}}}for(x,y)in pts{pix[(y+dy)*width+x+dx]=fill;}return Ok(pix);}anyhow::bail!("{text} does not fit")
 }
 fn rgba_png(path:&Path,pix:&[u8],w:usize,h:usize,pal:&[u16])->Result<()>{let mut rgba=Vec::new();for &i in pix{let p=pal[i as usize];for s in [0,5,10]{rgba.push((((p>>s)&31)*255/31)as u8);}rgba.push(if i==0{0}else{255});}let mut e=png::Encoder::new(BufWriter::new(fs::File::create(path)?),w as u32,h as u32);e.set_color(png::ColorType::Rgba);e.set_depth(png::BitDepth::Eight);e.write_header()?.write_image_data(&rgba)?;Ok(())}

 fn patch_header(current:&[u8],original:&[u8],labels:&[Label],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  ensure!(labels.len()==40,"header label count");let before=decompress(current,true)?;let source=decompress(original,true)?;ensure!(before.len()==source.len()&&before[..3104]==source[..3104],"header metadata/palettes changed");let mut after=before.clone();let mut ranges=Vec::<[usize;2]>::new();let mut reports=Vec::new();
  for l in labels {let[x,y,width,height]=l.cell;let cell=Cell{x,y,width,height};let own=read_indexed_cell_in_prefix(&source,0,cell)?;ensure!(read_indexed_cell_in_prefix(&before,0,cell)?==own,"target header cell already changed: {}",l.id);let(fill,outline)=match l.palette {31=>(14,2),25=>(14,2),24=>(2,1),_=>(1,15)};let mut pix=canvas(font,&l.text,width,height,fill,outline)?;if l.palette==24{let ramp=[2,6,10,14,15,11,7,4,12,13,9,5,8,3];for(i,v)in pix.iter_mut().enumerate(){if *v==fill{*v=ramp[(i%width)*ramp.len()/width];}}}let writes=write_indexed_cell_in_prefix(&mut after,0,cell,&pix)?;ensure!(writes.iter().all(|r|ranges.iter().all(|p|r[0]>=p[1]||p[0]>=r[1])),"overlapping header labels");ranges.extend(writes);let pal=read_4bpp_palette_words_in_prefix(&source,0,l.palette)?;rgba_png(&out.join("previews").join(format!("{}.png",l.id.replace('/',"slash").replace(' ',"-"))),&pix,width,height,&pal)?;reports.push(json!({"id":l.id,"cell":l.cell,"palette":l.palette}));}
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|r[0]<=i&&i<r[1])),"header write escaped owned cells");let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let compressed=stored.len();stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"header compression/readback");Ok((stored,json!({"labels":reports,"compressed_bytes":compressed,"fixed_slot":current.len(),"all_other_pixels_and_palettes_preserved":true})))
 }
 fn patch_layout(current:&[u8],source:&[u8])->Result<(Vec<u8>,Value)>{
  for(a,b)in [(0x2f20usize,0x2fecusize),(0x23c00,0x24aa8),(0x24ecc,0x25c4c),(0x1f84,0x201c),(0x18514,0x18900)]{ensure!(current[a..b]==source[a..b],"status/diary consumer changed at {a:x}");}
  ensure!(source[0x2f98..0x2fb0]==[0,40,104,24,104,40,80,5,184,40,64,5,40,160,20,25,60,160,80,25,0,160,20,25],"status descriptors changed");let mut after=current.to_vec();let changes=[(0x2fbc,208u16),(0x2fc0,88),(0x2fdc,168),(0x2fe0,188),(0x2fe4,228),(0x2fe8,248)];for(at,v)in changes{after[at..at+2].copy_from_slice(&v.to_le_bytes());}ensure!(current.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||changes.iter().any(|(p,_)|i>=*p&&i<*p+2)),"layout write escaped DOB positions");ensure!(source[0x30f8..0x316a].chunks_exact(2).enumerate().all(|(i,p)|u16::from_le_bytes(p.try_into().unwrap())as usize==113+i),"57-item lookup binding changed");Ok((after,json!({"birthday":"BIRTHDAY MM/DD; native two-digit suppression and original saved values preserved","owned_u16_positions":changes.map(|(p,_)|p),"code_bytes_and_saved_records_preserved":true})))
 }
 fn run()->Result<()>{
  let master=PathBuf::from(std::env::var("JG2_V28_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V28_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V28_OUTPUT")?);let packet_path=PathBuf::from(std::env::var("JG2_V28_PACKET")?);
  ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"disc identity");ensure!(sha256_file(&packet_path)?==PACKET_HASH,"private translation packet identity");ensure!(!out.exists(),"output exists");
  let packet:Packet=serde_json::from_slice(&fs::read(&packet_path)?)?;ensure!(packet.source_sha256==SOURCE_HASH&&packet.source_pattern_count==57&&packet.source_coordinate_count==4446&&packet.runtime_images==78&&packet.entries.len()==57,"packet scope");let labels=packet.labels;let entries=packet.entries.into_iter().map(|e|(e.fingerprint.clone(),e)).collect::<BTreeMap<_,_>>();ensure!(entries.len()==57,"duplicate source patterns");
  let fontbytes=fs::read(std::env::var("JG2_V28_FONT")?)?;let font=fontdue::Font::from_bytes(fontbytes.clone(),fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  assert_pointer_consumer(&rebuild::read_record(&master,"DAT1/MGAME.BIN")?.1,&rebuild::read_record(&source,"DAT1/MGAME.BIN")?.1)?;fs::create_dir_all(out.join("previews"))?;
  let originals=super::super::sources::load_dialogue_runtime_image_sources(&source)?;ensure!(originals.len()==78,"runtime population");let mut replacements=BTreeMap::new();let mut reports=Vec::new();let mut seen=BTreeMap::new();let mut previews=BTreeSet::new();
  for s in originals{eprintln!("Status item descriptions: {}",s.path);let current=rebuild::read_record(&master,&s.path)?.1;let(data,report)=patch_bank(&s.path,&current,&s.data,&font,&entries,&mut seen,&mut previews,&out)?;if data!=current{replacements.insert(s.path.clone(),data);}reports.push(report);}
  for(fp,e)in &entries{ensure!(seen.get(fp)==Some(&e.coordinate_count),"source help fingerprint coverage {}",e.id);}
  for month in ["04","06","08","09","11"]{let bp=format!("DAT2/MGG{month}.BZZ");let mut bundle=rebuild::read_record(&master,&bp)?.1;let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5,"school bundle geometry");let before=bundle.clone();for(school,slot)in ["T","O","P","G","J"].into_iter().zip(slots){let path=format!("DAT2/MGG{month}{school}.BIZ");let current=rebuild::read_record(&master,&path)?.1;ensure!(bundle[slot.compressed_range()]==current,"loaded bundle binding {path}");if let Some(data)=replacements.get(&path){ensure!(data.len()==slot.compressed_size,"bundle record extent");bundle[slot.compressed_range()].copy_from_slice(data);}}if bundle!=before{replacements.insert(bp,bundle);}}
  let(header,header_report)=patch_header(&rebuild::read_record(&master,"DAT2/MGCOCK.TIZ")?.1,&rebuild::read_record(&source,"DAT2/MGCOCK.TIZ")?.1,&labels,&font,&out)?;replacements.insert("DAT2/MGCOCK.TIZ".into(),header);
  let(game,layout_report)=patch_layout(&rebuild::read_record(&master,"DAT1/MGAME.BIN")?.1,&rebuild::read_record(&source,"DAT1/MGAME.BIN")?.1)?;replacements.insert("DAT1/MGAME.BIN".into(),game);
  let bin=out.join("justice-gakuen2-status-diary-v28.bin");let repl=replacements.iter().map(|(p,d)|rebuild::FixedRecordReplacement{path:p,data:d}).collect::<Vec<_>>();let changed_records=rebuild::copy_and_replace_records(&master,&bin,&repl)?;for r in &repl{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback");}let allowed=changed_records.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|l|allowed.contains(l)),"changed-sector ownership");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector EDC/ECC");}
  ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH&&sha256_file(&packet_path)?==PACKET_HASH,"input changed");let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-status-diary-v28.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
  let translated:usize=reports.iter().map(|r|r["translated"].as_u64().unwrap()as usize).sum();let preserved:usize=reports.iter().map(|r|r["preserved_custom"].as_array().unwrap().len()).sum();ensure!(translated+preserved==4446,"coverage accounting");
  let report=json!({"kind":"Status and diary English v28","master_sha256":MASTER_HASH,"source_sha256":SOURCE_HASH,"packet_sha256":PACKET_HASH,"font_sha256":sha256_bytes(&fontbytes),"output_sha256":hash,"cue":cue,"changed_sector_count":changed.len(),"runtime_images":78,"source_patterns":57,"source_item_coordinates":4446,"translated_coordinates":translated,"custom_coordinates_preserved":preserved,"preview_count":previews.len(),"all_untargeted_payloads_records_and_saved_names_preserved":true,"graphics":header_report,"birthday_layout":layout_report,"graphics_labels":40,"records":reports});fs::write(out.join("status-diary-v28-report.json"),serde_json::to_vec_pretty(&report)?)?;
  println!("STATUS_DIARY_V28_COMPLETE=1\nOUTPUT_SHA256={hash}\nTRANSLATED_COORDINATES={translated}\nCUSTOM_COORDINATES_PRESERVED={preserved}\nCHANGED_RAW_SECTORS={}\nCUE={}",changed.len(),cue.display());Ok(())
 } #[test] fn english_project_status_diary_v28_preservation()->Result<()>{
  let source=PathBuf::from(std::env::var("JG2_V28_SOURCE")?);let original=rebuild::read_record(&source,"DAT2/MGC01.BIZ")?.1;let decoded=decompress(&original,true)?;let at=atlas::parse_dialogue_atlas(&decoded)?;let mut old=pointer_banks(&decoded)?;
  let font=fontdue::Font::from_bytes(fs::read(std::env::var("JG2_V28_FONT")?)?,fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  let mut current=decoded.clone();let(codes,_)=install_glyphs(&decoded,&mut current,&old,&at,&BTreeSet::from(['Z']),&font)?;
  let ms=&mut old.iter_mut().find(|(s,_)|*s==2).context("test selector")?.1;let mut custom=words(&ms[113]);custom[2]=codes[&'Z'];ms[113]=bytes(custom);let preserved=ms[113].clone();
  let dates=&mut old.iter_mut().find(|(s,_)|*s==3).unwrap().1;let mut date=words(&dates[0]);let body=date.iter().position(|c|*c==0x3000).unwrap()+1;date[body]=codes[&'Z'];dates[0]=bytes(date);let prior_date=dates[0].clone();
  compact(&mut current,&old)?;let profile=crate::paged_compression::source_paged_compression_profile(&original)?;let mut encoded=crate::paged_compression::compress_page_safe_image_in_slot(&current,profile,original.len())?;encoded.resize(original.len(),0);
  let packet:Packet=serde_json::from_slice(&fs::read(std::env::var("JG2_V28_PACKET")?)?)?;let entries=packet.entries.into_iter().map(|e|(e.fingerprint.clone(),e)).collect::<BTreeMap<_,_>>();
  let out=std::env::temp_dir().join(format!("jg2-v28-preservation-{}",std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH)?.as_nanos()));ensure!(!out.exists(),"test path collision");fs::create_dir_all(out.join("previews"))?;
  let(result,report)=patch_bank("DAT2/MGC01.BIZ",&encoded,&original,&font,&entries,&mut BTreeMap::new(),&mut BTreeSet::new(),&out)?;let actual=pointer_banks(&decompress(&result,true)?)?;let ms=&actual.iter().find(|(s,_)|*s==2).unwrap().1;
  ensure!(ms[113]==preserved,"custom item overwritten");ensure!(report["translated"]==56&&report["preserved_custom"].as_array().unwrap().len()==1,"mixed item accounting");ensure!(actual.iter().find(|(s,_)|*s==3).unwrap().1[0]==prior_date,"prior custom date changed");fs::remove_dir_all(out)?;Ok(())
 }
 #[test] fn english_project_status_diary_v28()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(run)?.join().unwrap()}
}

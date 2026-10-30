// ENGLISH_PROJECT_POOL_CLUB_V22
mod english_pool_club_v22 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde_json::{json,Value};
 use super::super::{atlas,parser,tokens};
 use crate::{pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild,tim::{Cell,read_indexed_cell_in_prefix,write_indexed_cell_in_prefix,read_4bpp_palette_words_in_prefix,read_8bpp_palette_words_in_prefix,write_8bpp_indexed_cell_in_prefix}};
 use psx_r3000a::{Instruction,Register,encode_le_bytes};
 const MASTER_HASH:&str="f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const TEXT_HASH:&str="0373879a09b285164f8ac7e4424cfdb8bf466fe09e2b7e40c985563d7de93ed1";
 const PACKET:&str=r###"PACKET_REPLACE"###;
 const DIALOGUE:&str="DAT2/MGG04T.BIZ";
 const BUNDLE:&str="DAT2/MGG04.BZZ";
 const GRAPHICS:&str="DAT2/MGBGG04.BZZ";
 const HEADER:&str="DAT2/MGCOCK.TIZ";
 const MGAME:&str="DAT1/MGAME.BIN";
 const ARENA:usize=0x31000;
 const LIMIT:usize=0x4a000;
 type Banks=Vec<(usize,Vec<Vec<u8>>)>;
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
  while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed control placeholder")?;let id=rest[1..end].parse::<usize>()?;ensure!(id==next&&id<protected.len(),"control placeholder order/count");let(code,args)=&protected[id];w.push(*code);w.extend(args);if (0x2000..=0x2009).contains(code){columns+=6;}next+=1;rest=&rest[end+1..];
   }else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c=='\n'{ensure!(columns<=20,"line wider than 20 cells");lines+=1;columns=0;w.push(0x3000);}else{ensure!(c.is_ascii(),"non-ASCII translation");w.push(*codes.get(&c).with_context(||format!("missing ASCII glyph {c}"))?);columns+=1;}}
  }
  ensure!(next==protected.len(),"missing protected control placeholder");ensure!(columns<=20&&lines<=4,"translation exceeds native window");w.push(0x3001);let result=bytes(w);ensure!(controls(&result,at.fixed_cell_count,at.addressable_slot_count)?==controls(source,at.fixed_cell_count,at.addressable_slot_count)?,"protected controls changed");Ok(result)
 }
 fn chars_of(text:&str,set:&mut BTreeSet<char>)->Result<()>{let mut rest=text;while !rest.is_empty(){if rest.starts_with('{'){let end=rest.find('}').context("unclosed placeholder")?;rest=&rest[end+1..];}else{let c=rest.chars().next().unwrap();rest=&rest[c.len_utf8()..];if c!='\n'{ensure!(c.is_ascii(),"non-ASCII");set.insert(c);}}}Ok(())}
 fn patch_text(current:&[u8],font:&fontdue::Font)->Result<(Vec<u8>,Vec<u8>,Value)>{
  ensure!(sha256_bytes(current)==TEXT_HASH,"v21 Taiyo text identity changed");let before=decompress(current,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let legacy=parser::parse_dialogue_banks(&before)?;let banks=legacy.iter().map(|b|(b.selector_index,b.messages.iter().map(|m|m.data.clone()).collect())).collect::<Banks>();ensure!(pointer_banks(&before)?==banks,"native/legacy input parsing differs");let mut wanted=banks.clone();
  let packet:Value=serde_json::from_str(PACKET)?;let entries=packet["entries"].as_array().context("entries")?;ensure!(entries.len()==120,"translation population");let mut translations=BTreeMap::new();for sel in [0usize,1]{for e in entries{let i=e["index"].as_u64().context("index")? as usize;ensure!((57..=176).contains(&i),"entry outside scope");let key=format!("{sel}:{i}");let text=packet["overrides"][&key].as_str().or_else(||e["text"].as_str()).context("text")?.to_owned();ensure!(translations.insert((sel,i),text).is_none(),"duplicate coordinate");}}
  for i in 52..=55{translations.insert((2,i),packet["menu_help"][i.to_string()].as_str().context("menu help")?.to_owned());}ensure!(translations.len()==244,"target count");
  let mut codes=" !'(),-./?ABCDEFGHIJKLMNOPQRSTUVWYZ".chars().enumerate().map(|(i,c)|(c,892+i as u16)).collect::<BTreeMap<_,_>>();ensure!(codes.len()==35&&codes[&'Z']==926,"v21 glyph mapping");
  for(&c,&code)in &codes{let p=at.pixel_data_offset+code as usize*200;ensure!(p+200<=ARENA,"existing glyph outside atlas");ensure!(before[p..p+200].iter().any(|b|*b!=0)||c==' ',"v21 ASCII glyph missing");}
  let mut chars=BTreeSet::new();for text in translations.values(){chars_of(text,&mut chars)?;}let mut first=at.fixed_cell_count;let mut used=BTreeSet::new();for(_,ms)in &banks{for m in ms{for t in tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){used.insert(t.code as usize);}}}}
  for i in 0..at.addressable_slot_count{if used.contains(&i)||before[at.pixel_data_offset+i*200..at.pixel_data_offset+(i+1)*200].iter().any(|b|*b!=0){first=first.max(i+1);}}
  let mut after=before.clone();let mut next=first;for c in chars{if codes.contains_key(&c){continue;}ensure!(next<at.addressable_slot_count,"new glyph capacity");let(w,h,pts)=ink(font,&c.to_string(),14.0)?;ensure!(w<=18&&h<=18,"glyph bounds");let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;for &(x,y)in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}for(x,y)in pts{pix[(y+dy)*20+x+dx]=14;}let p=at.pixel_data_offset+next*200;ensure!(after[p..p+200].iter().all(|b|*b==0),"glyph slot used");for(i,pair)in pix.chunks_exact(2).enumerate(){after[p+i]=pair[0]|pair[1]<<4;}codes.insert(c,next as u16);next+=1;}
  for(&(sel,i),text)in &translations{let ms=&mut wanted.iter_mut().find(|(s,_)|*s==sel).context("selector")?.1;let old=ms.get(i).context("message")?;
   if matches!(i,118|119)&&sel<2{ensure!(text.lines().count()==3&&text.lines().all(|l|l.len()<=20&&l.as_bytes().get(10).is_some_and(|b|*b!=b' ')),"two-column club menu geometry");}
   if sel<2&&[123,127,131,135,139,143,147,151,155,161,175].contains(&i){ensure!(text.lines().count()==2,"choice row population");}
   ms[i]=encode_target(text,old,&codes,&at).with_context(||format!("selector {sel} entry {i}"))?;
  }
  let naive=wanted.iter().map(|(_,ms)|ms.iter().map(Vec::len).sum::<usize>()+(ms.len()+1)*4).sum::<usize>();let(used_bytes,aliases)=compact(&mut after,&wanted)?;ensure!(aliases>0,"no shared payloads");
  let parsed=pointer_banks(&after)?;ensure!(parsed==wanted,"compacted readback");for((sel,ms),(_,original))in parsed.iter().zip(&banks){for(i,m)in ms.iter().enumerate(){tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;if !translations.contains_key(&(*sel,i)){ensure!(m==&original[i],"earlier or unrelated message changed");}}}
  let lo=at.pixel_data_offset+first*200;let hi=at.pixel_data_offset+next*200;ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(lo..hi).contains(&i)||(ARENA..LIMIT).contains(&i)),"text change outside ownership");
  let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"text compression roundtrip");stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"padded text roundtrip");
  let report=json!({"translated_story_entries":240,"translated_menu_help_entries":4,"new_glyph_start":first,"new_glyph_count":next-first,"glyph_codes":codes,"arena_used_bytes":used_bytes,"arena_capacity_bytes":LIMIT-ARENA-32,"unshared_arena_bytes":naive,"shared_message_references":aliases,"deduplicated_bytes":naive-used_bytes,"compressed_bytes":length,"fixed_slot":current.len(),"input_sha256":TEXT_HASH,"patched_sha256":sha256_bytes(&stored),"earlier_and_untargeted_payloads_preserved":true,"scripts_preserved":true,"protected_controls_preserved":true,"native_pointer_readback_verified":true});Ok((stored,after,report))
 }
 fn canvas(font:&fontdue::Font,text:&str,width:usize,height:usize,fill:u8,outline:u8)->Result<Vec<u8>>{
  for size in [16.0f32,15.0,14.0,13.0,12.0,11.0,10.0,9.0]{let(w,h,pts)=ink(font,text,size)?;if w+2>width||h+2>height{continue;}let dx=(width-w)/2;let dy=(height-h)/2;let mut pix=vec![0u8;width*height];for &(x,y)in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{pix[yy*width+xx]=outline;}}}for(x,y)in pts{pix[(y+dy)*width+x+dx]=fill;}return Ok(pix);}anyhow::bail!("{text} does not fit")
 }
 fn rgba_png(path:&Path,pix:&[u8],w:usize,h:usize,pal:&[u16])->Result<()>{let mut rgba=Vec::new();for &i in pix{let p=pal[i as usize];for s in [0,5,10]{rgba.push((((p>>s)&31)*255/31)as u8);}rgba.push(if i==0{0}else{255});}let mut e=png::Encoder::new(BufWriter::new(fs::File::create(path)?),w as u32,h as u32);e.set_color(png::ColorType::Rgba);e.set_depth(png::BitDepth::Eight);e.write_header()?.write_image_data(&rgba)?;Ok(())}
 fn nearest(pal:&[u16],rgb:[i32;3])->u8{(0..pal.len()).min_by_key(|&i|[0,5,10].iter().enumerate().map(|(c,s)|(((pal[i]>>s)&31)as i32*255/31-rgb[c]).pow(2)).sum::<i32>()).unwrap()as u8}

fn action_program() -> Vec<Instruction> {
    use Instruction::*;
    // Only the text loop changes. The descriptor extent and background drawing
    // remain native. Register::S4 offsets the first slice; Register::S7 advances adjacent slices.
    // The supported descriptor table contains only positive counts. Its 255
    // sentinel takes the separate single-sprite path before this division.
    vec![
        // All sliced labels are authored, including movement. Preserve the
        // original block size without retaining its obsolete row exception.
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::ZERO,
            rt: Register::ZERO,
            shift: 0,
        },
        Sll {
            rd: Register::T0,
            rt: Register::V1,
            shift: 1,
        },
        Addu {
            rd: Register::T0,
            rs: Register::T0,
            rt: Register::V1,
        },
        Sll {
            rd: Register::T0,
            rt: Register::T0,
            shift: 2,
        }, // count * 12
        Subu {
            rd: Register::S4,
            rs: Register::A0,
            rt: Register::T0,
        },
        Addiu {
            rt: Register::S7,
            rs: Register::ZERO,
            immediate: 24,
        },
        Addu {
            rd: Register::S5,
            rs: Register::ZERO,
            rt: Register::ZERO,
        },
        Lui {
            rt: Register::S6,
            immediate: 0x801f,
        },
        Ori {
            rt: Register::S6,
            rs: Register::S6,
            immediate: 0x608c,
        },
        Srl {
            rd: Register::FP,
            rt: Register::S7,
            shift: 1,
        },
        Addiu {
            rt: Register::S3,
            rs: Register::ZERO,
            immediate: 0xc0,
        },
    ]
}

 fn patch_menu_code(current:&[u8],source:&[u8])->Result<Vec<u8>>{
  assert_pointer_consumer(current,source)?;
  let rows:[[u8;8];4]=[[3,9,4,168,72,60,12,0],[2,9,4,144,96,60,12,0],[5,9,4,0,144,60,12,0],[2,9,4,120,144,60,12,0]];
  ensure!(current.get(0x1f84..0x1fa4)==Some(rows.concat().as_slice()),"action menu descriptors changed");
  let native:[u32;18]=[0x0043001a,0x14600002,0,0x0007000d,0x2401ffff,0x14610004,0x3c018000,0x14410002,0,0x0006000d,0x0000b812,0x10600032,0x0000a821,0x3c16801f,0x36d6608c,0x0017f042,0x0000a021,0x241300c0];
  let old=native.into_iter().flat_map(u32::to_le_bytes).collect::<Vec<_>>();let offset=0x19454;ensure!(current.get(offset..offset+72)==Some(old.as_slice()),"menu spacing source changed");let new=encode_le_bytes(&action_program(),0x800bb454)?;ensure!(new.len()==72,"spacing replacement extent");let mut after=current.to_vec();after[offset..offset+72].copy_from_slice(&new);ensure!(after[..offset]==current[..offset]&&after[offset+72..]==current[offset+72..],"other MGAME bytes changed");Ok(after)
 }
 fn patch_header(current:&[u8],original:&[u8],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  let before=decompress(current,true)?;let source=decompress(original,true)?;let mut after=before.clone();let entries=[("CONTINUE",Cell{x:424,y:72,width:72,height:24}),("MOVE",Cell{x:400,y:96,width:48,height:24}),("STATUS",Cell{x:256,y:144,width:120,height:24}),("DIARY",Cell{x:376,y:144,width:48,height:24})];let mut ranges=Vec::new();
  for (name,cell)in entries{let old=read_indexed_cell_in_prefix(&before,0,cell)?;ensure!(old==read_indexed_cell_in_prefix(&source,0,cell)?,"menu cell {name} already changed");let p=canvas(font,name,cell.width,cell.height,1,15)?;ranges.extend(write_indexed_cell_in_prefix(&mut after,0,cell,&p)?);for phase in [4usize,5]{let pal=read_4bpp_palette_words_in_prefix(&before,0,phase)?;ensure!(pal[1]&31>=30||((pal[1]>>5)&31)>=30,"menu palette fill changed");rgba_png(&out.join(format!("menu-{}-palette{phase}-v22.png",name.to_lowercase())),&p,cell.width,cell.height,&pal)?;}}
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|i>=r[0]&&i<r[1])),"header change escaped menu cells");let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"header compression");stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"padded header readback");Ok((stored,json!({"labels":["CONTINUE","MOVE","STATUS","DIARY"],"compressed_bytes":length,"fixed_slot":current.len(),"all_other_header_bytes_preserved":true,"native_palettes_preserved":true})))
 }
 fn patch_locations(current:&[u8],original:&[u8],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  ensure!(sha256_bytes(original)=="7fe06a64a164abd70fe71d0ddf2e6e93ff43b6accd0ffd779f1f61128d5e3ebc","original graphics identity");let slots=crate::tzz::parse_tzz(current)?;let src_slots=crate::tzz::parse_tzz(original)?;ensure!(slots==src_slots,"graphics geometry changed");
  let specs=[(2usize,"WALKWAY"),(3,"POOLSIDE"),(4,"CLUB BUILDING"),(5,"FIELD"),(6,"GYM"),(7,"FIELD"),(8,"SUMO ROOM"),(9,"CLASSROOM"),(10,"CLASSROOM"),(12,"CLASSROOM"),(13,"CLASSROOM")];let mut patterns=Vec::<(String,Vec<u8>,Vec<u8>)>::new();
  for(member,name)in specs{let d=decompress(&original[src_slots[member].compressed_range()],false)?;let tim=crate::embedded_tim::parse_embedded_tim_at(&d,0)?;ensure!(tim.bits_per_pixel==8&&tim.pixel_width==256&&tim.pixel_height==244,"location texture shape");let source=d[..tim.total_size].to_vec();if patterns.iter().any(|(_,p,_)|p==&source){continue;}let pal=read_8bpp_palette_words_in_prefix(&source,0,0)?;let fill=nearest(&pal,[255,255,255]);let outline=nearest(&pal,[25,25,25]);let text=canvas(font,name,76,22,fill,outline)?;let mut label=vec![0u8;128*24];for y in 0..22{label[(y+1)*128+4..(y+1)*128+80].copy_from_slice(&text[y*76..y*76+76]);}let mut after=source.clone();let allowed=write_8bpp_indexed_cell_in_prefix(&mut after,0,Cell{x:0,y:220,width:128,height:24},&label)?;ensure!(source.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||allowed.iter().any(|r|i>=r[0]&&i<r[1])),"location strip ownership");rgba_png(&out.join(format!("location-{}-{}-v22.png",name.to_lowercase().replace(' ',"-"),member)),&label,128,24,&pal)?;patterns.push((name.into(),source,after));}
  let mut archive=current.to_vec();let mut counts=BTreeMap::<String,usize>::new();let mut report=Vec::new();
  for slot in &slots{let stored=&current[slot.compressed_range()];let before=decompress(stored,true)?;let mut after=before.clone();let mut ranges=Vec::new();for(name,source,target)in &patterns{for off in (0..=before.len().saturating_sub(source.len())).step_by(4){if before.get(off..off+source.len())==Some(source.as_slice()){after[off..off+source.len()].copy_from_slice(target);ranges.push(off..off+source.len());*counts.entry(name.clone()).or_default()+=1;}}}
   if after==before{continue;}ensure!(stored==&original[src_slots[slot.index].compressed_range()],"target location member already changed");ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|r.contains(&i))),"graphics member ownership");let profile=crate::paged_compression::source_paged_compression_profile(stored)?;let prefix=before.iter().zip(&after).take_while(|(a,b)|a==b).count()&!1;let(encoded,kept)=crate::paged_compression::compress_on_source_final_page_with_preserved_prefix(&after,stored,profile,prefix)?;let new=crate::paged_compression::source_paged_compression_profile(&encoded)?;ensure!((new.stream_byte_count-1)/0x800==(profile.stream_byte_count-1)/0x800&&new.maximum_match_words<=profile.maximum_match_words&&new.maximum_control_block_output_words<=profile.maximum_control_block_output_words&&kept.encoded_byte_count>0,"native graphics compression contract");ensure!(encoded.len()<=slot.compressed_size,"location member {} exceeds slot",slot.index);ensure!(decompress(&encoded,false)?==after,"location compression readback");let length=encoded.len();let mut padded=encoded;padded.resize(slot.compressed_size,0);ensure!(decompress(&padded,true)?==after,"padded location readback");archive[slot.compressed_range()].copy_from_slice(&padded);report.push(json!({"member":slot.index,"compressed_bytes":length,"fixed_slot":slot.compressed_size}));
  }
  ensure!(counts.get("WALKWAY").copied().unwrap_or(0)>0&&counts.get("POOLSIDE").copied().unwrap_or(0)>0,"required locations not found");ensure!(crate::tzz::parse_tzz(&archive)?==slots,"archive table changed");Ok((archive,json!({"copies":counts,"members":report,"all_other_graphics_preserved":true,"palettes_preserved":true})))
 }
 fn run()->Result<()>{
  let master=PathBuf::from(std::env::var("JG2_V22_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V22_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V22_OUTPUT")?);ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"disc identity mismatch");ensure!(!out.exists(),"output directory exists");fs::create_dir_all(&out)?;
  let font_bytes=fs::read(std::env::var("JG2_V22_FONT")?)?;let font=fontdue::Font::from_bytes(font_bytes.clone(),fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  let text_before=rebuild::read_record(&master,DIALOGUE)?.1;let bundle_before=rebuild::read_record(&master,BUNDLE)?.1;let graphic_before=rebuild::read_record(&master,GRAPHICS)?.1;let header_before=rebuild::read_record(&master,HEADER)?.1;let game_before=rebuild::read_record(&master,MGAME)?.1;
  ensure!(sha256_bytes(&header_before)=="91e79bd579837c032e0284c15683c076c27a86f0c26299f00ad0539410ca6e9b","v21 shared header identity");ensure!(sha256_bytes(&game_before)=="e8885452773fcf91bef4b85b2363a37d07547ab3c04b463c92c658d66cc1492f","v21 MGAME identity");
  let original_graphics=rebuild::read_record(&source,GRAPHICS)?.1;let original_header=rebuild::read_record(&source,HEADER)?.1;let original_game=rebuild::read_record(&source,MGAME)?.1;assert_pointer_consumer(&game_before,&original_game)?;
  let(text,decoded,text_report)=patch_text(&text_before,&font)?;let mut bundle=bundle_before.clone();let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5&&bundle[slots[0].compressed_range()]==text_before,"Taiyo bundle binding");bundle[slots[0].compressed_range()].copy_from_slice(&text);ensure!(bundle[..slots[0].offset]==bundle_before[..slots[0].offset]&&bundle[slots[0].offset+slots[0].compressed_size..]==bundle_before[slots[0].offset+slots[0].compressed_size..],"other school dialogue changed");
  let(graphic,graphics_report)=patch_locations(&graphic_before,&original_graphics,&font,&out)?;let(header,header_report)=patch_header(&header_before,&original_header,&font,&out)?;let game=patch_menu_code(&game_before,&original_game)?;
  let bin=out.join("justice-gakuen2-pool-club-v22.bin");let replacements=[rebuild::FixedRecordReplacement{path:DIALOGUE,data:&text},rebuild::FixedRecordReplacement{path:BUNDLE,data:&bundle},rebuild::FixedRecordReplacement{path:GRAPHICS,data:&graphic},rebuild::FixedRecordReplacement{path:HEADER,data:&header},rebuild::FixedRecordReplacement{path:MGAME,data:&game}];let replaced=rebuild::copy_and_replace_records(&master,&bin,&replacements)?;
  for r in &replacements{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback failed");}let allowed=replaced.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|l|allowed.contains(l)),"changed sectors outside owned records");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector checksum failed");}ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"input changed");
  let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-pool-club-v22.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
  if std::env::var("JG2_V22_QA_EXPORT").is_ok(){fs::write(out.join("MGG04T-v22-private.decoded"),decoded)?;}
  let report=json!({"kind":"Taiyo pool/club and shared action labels English v22","source_sha256":SOURCE_HASH,"master_sha256":MASTER_HASH,"output_sha256":hash,"font_sha256":sha256_bytes(&font_bytes),"changed_sector_count":changed.len(),"cue":cue.display().to_string(),"text":text_report,"graphics":graphics_report,"header":header_report,"mgame_changed_range":[0x19454,0x19454+72],"earlier_and_untargeted_layers_preserved":true,"other_schools_dialogue_preserved":true,"native_pointer_consumer_verified":true});fs::write(out.join("pool-club-v22-report.json"),serde_json::to_vec_pretty(&report)?)?;eprintln!("POOL_CLUB_V22_COMPLETE=1\nOUTPUT_SHA256={hash}\nCHANGED_RAW_SECTORS={}\nCUE={}\n{}",changed.len(),cue.display(),serde_json::to_string_pretty(&report)?);Ok(())
 }
 #[test] fn english_project_pool_club_v22()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(run)?.join().unwrap()}
 #[test] fn pool_club_v22_shared_pointer_roundtrip()->Result<()>{let a=bytes(vec![1,0x3001]);let b=bytes(vec![2,0x3003,0x3001,3,0x3001]);let expected=vec![(0,vec![a.clone(),b.clone(),a.clone()]),(1,vec![b.clone(),a])];let mut d=vec![0u8;0x51800];let(_,aliases)=compact(&mut d,&expected)?;ensure!(aliases==3&&pointer_banks(&d)?==expected,"alias roundtrip");let p=u32_at(&d,ARENA)? as usize-0x800d0000;d[p..p+4].copy_from_slice(&0x800d0000u32.to_le_bytes());ensure!(pointer_banks(&d).is_err(),"invalid pointer accepted");Ok(())}
}

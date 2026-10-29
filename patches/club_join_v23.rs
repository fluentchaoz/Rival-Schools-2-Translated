// ENGLISH_PROJECT_POOL_CLUB_V23
mod english_club_join_v23 {
 use anyhow::{Context,Result,ensure};
 use std::{fs,path::{Path,PathBuf},collections::{BTreeMap,BTreeSet},io::BufWriter};
 use serde_json::{json,Value};
 use super::super::{atlas,tokens};
 use crate::{pipeline::{sha256_bytes,sha256_file},compression::decompress,disc::rebuild,tim::{Cell,read_indexed_cell_in_prefix,write_indexed_cell_in_prefix,read_4bpp_palette_words_in_prefix,read_8bpp_palette_words_in_prefix,write_8bpp_indexed_cell_in_prefix}};
 const MASTER_HASH:&str="b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e";
 const SOURCE_HASH:&str="0fce6eda2082d91af5a963c73fbf80a7935b1ebd5446dff5d01e548370fabe8e";
 const TEXT_HASH:&str="df9fca06ae4edac941a36a05a5ffb35d17b87e9f28355b714dc97886fb0c5081";
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
  ensure!(sha256_bytes(current)==TEXT_HASH,"v22 Taiyo text identity changed");let before=decompress(current,true)?;let at=atlas::parse_dialogue_atlas(&before)?;let banks=pointer_banks(&before)?;let mut wanted=banks.clone();
  let packet:Value=serde_json::from_str(PACKET)?;let entries=packet["entries"].as_array().context("entries")?;ensure!(entries.len()==171,"translation population");let mut translations=BTreeMap::new();for sel in [0usize,1]{for e in entries{let i=e["index"].as_u64().context("index")? as usize;ensure!((177..=347).contains(&i),"entry outside scope");let key=format!("{sel}:{i}");let text=packet["overrides"][&key].as_str().or_else(||e["text"].as_str()).context("text")?.to_owned();ensure!(translations.insert((sel,i),text).is_none(),"duplicate coordinate");}}
  ensure!(translations.len()==342,"target count");
  let mut codes=" !'(),-./?ABCDEFGHIJKLMNOPQRSTUVWYZ".chars().enumerate().map(|(i,c)|(c,892+i as u16)).collect::<BTreeMap<_,_>>();codes.extend([(':',927),('>',928),('X',929)]);ensure!(codes.len()==38&&codes[&'X']==929,"v22 glyph mapping");
  for(&c,&code)in &codes{let p=at.pixel_data_offset+code as usize*200;ensure!(p+200<=ARENA,"existing glyph outside atlas");ensure!(before[p..p+200].iter().any(|b|*b!=0)||c==' ',"v21 ASCII glyph missing");}
  let mut chars=BTreeSet::new();for text in translations.values(){chars_of(text,&mut chars)?;}let mut first=at.fixed_cell_count;let mut used=BTreeSet::new();for(_,ms)in &banks{for m in ms{for t in tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?.tokens{if matches!(t.kind,tokens::DialogueTokenKind::FixedGlyph|tokens::DialogueTokenKind::RuntimeExtensionGlyph){used.insert(t.code as usize);}}}}
  for i in 0..at.addressable_slot_count{if used.contains(&i)||before[at.pixel_data_offset+i*200..at.pixel_data_offset+(i+1)*200].iter().any(|b|*b!=0){first=first.max(i+1);}}
  let mut after=before.clone();let mut next=first;for c in chars{if codes.contains_key(&c){continue;}ensure!(next<at.addressable_slot_count,"new glyph capacity");let(w,h,pts)=ink(font,&c.to_string(),14.0)?;ensure!(w<=18&&h<=18,"glyph bounds");let mut pix=vec![0u8;400];let dx=(20-w)/2;let dy=(20-h)/2;for &(x,y)in &pts{for yy in (y+dy).saturating_sub(1)..=(y+dy+1).min(19){for xx in (x+dx).saturating_sub(1)..=(x+dx+1).min(19){pix[yy*20+xx]=4;}}}for(x,y)in pts{pix[(y+dy)*20+x+dx]=14;}let p=at.pixel_data_offset+next*200;ensure!(after[p..p+200].iter().all(|b|*b==0),"glyph slot used");for(i,pair)in pix.chunks_exact(2).enumerate(){after[p+i]=pair[0]|pair[1]<<4;}codes.insert(c,next as u16);next+=1;}
  for(&(sel,i),text)in &translations{let ms=&mut wanted.iter_mut().find(|(s,_)|*s==sel).context("selector")?.1;let old=ms.get(i).context("message")?;
   if [182usize,203,224,245,266,287,308,329,196,217,238,259,280,301,322,343].contains(&i){ensure!(text.lines().count()==2,"choice row population");}
   ms[i]=encode_target(text,old,&codes,&at).with_context(||format!("selector {sel} entry {i}"))?;
  }
  let naive=wanted.iter().map(|(_,ms)|ms.iter().map(Vec::len).sum::<usize>()+(ms.len()+1)*4).sum::<usize>();let(used_bytes,aliases)=compact(&mut after,&wanted)?;ensure!(aliases>0,"no shared payloads");
  let parsed=pointer_banks(&after)?;ensure!(parsed==wanted,"compacted readback");for((sel,ms),(_,original))in parsed.iter().zip(&banks){for(i,m)in ms.iter().enumerate(){tokens::tokenize_dialogue_message(&words(m),at.fixed_cell_count,at.addressable_slot_count)?;if !translations.contains_key(&(*sel,i)){ensure!(m==&original[i],"earlier or unrelated message changed");}}}
  let lo=at.pixel_data_offset+first*200;let hi=at.pixel_data_offset+next*200;ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||(lo..hi).contains(&i)||(ARENA..LIMIT).contains(&i)),"text change outside ownership");
  let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"text compression roundtrip");stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"padded text roundtrip");
  let report=json!({"translated_story_entries":342,"new_glyph_start":first,"new_glyph_count":next-first,"glyph_codes":codes,"arena_used_bytes":used_bytes,"arena_capacity_bytes":LIMIT-ARENA-32,"unshared_arena_bytes":naive,"shared_message_references":aliases,"deduplicated_bytes":naive-used_bytes,"compressed_bytes":length,"fixed_slot":current.len(),"input_sha256":TEXT_HASH,"patched_sha256":sha256_bytes(&stored),"earlier_and_untargeted_payloads_preserved":true,"scripts_preserved":true,"protected_controls_preserved":true,"native_pointer_readback_verified":true});Ok((stored,after,report))
 }
 fn canvas(font:&fontdue::Font,text:&str,width:usize,height:usize,fill:u8,outline:u8)->Result<Vec<u8>>{
  for size in [16.0f32,15.0,14.0,13.0,12.0,11.0,10.0,9.0]{let(w,h,pts)=ink(font,text,size)?;if w+2>width||h+2>height{continue;}let dx=(width-w)/2;let dy=(height-h)/2;let mut pix=vec![0u8;width*height];for &(x,y)in &pts{for yy in y+dy-1..=y+dy+1{for xx in x+dx-1..=x+dx+1{pix[yy*width+xx]=outline;}}}for(x,y)in pts{pix[(y+dy)*width+x+dx]=fill;}return Ok(pix);}anyhow::bail!("{text} does not fit")
 }
 fn rgba_png(path:&Path,pix:&[u8],w:usize,h:usize,pal:&[u16])->Result<()>{let mut rgba=Vec::new();for &i in pix{let p=pal[i as usize];for s in [0,5,10]{rgba.push((((p>>s)&31)*255/31)as u8);}rgba.push(if i==0{0}else{255});}let mut e=png::Encoder::new(BufWriter::new(fs::File::create(path)?),w as u32,h as u32);e.set_color(png::ColorType::Rgba);e.set_depth(png::BitDepth::Eight);e.write_header()?.write_image_data(&rgba)?;Ok(())}
 fn nearest(pal:&[u16],rgb:[i32;3])->u8{(0..pal.len()).min_by_key(|&i|[0,5,10].iter().enumerate().map(|(c,s)|(((pal[i]>>s)&31)as i32*255/31-rgb[c]).pow(2)).sum::<i32>()).unwrap()as u8}
 fn patch_header(current:&[u8],original:&[u8],mgame:&[u8],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  for(start,end,hash)in [(0x1c74,0x1c86,"fa6b712afb3c7f95e8cbae8c1f894890564a095c557b45dd27787e8bcd6e52ad"),(0x14000,0x141f8,"ba156ef4736c8c77aa61ba8d36ecc4092cee9e77ba4b5731dcacd75392ad8389")]{ensure!(sha256_bytes(&mgame[start..end])==hash,"native club label consumer changed");}
  let before=decompress(current,true)?;let source=decompress(original,true)?;let mut after=before.clone();
  let entries=[("BASEBALL",192,48),("VOLLEYBALL",192,108),("SOCCER",192,88),("SUMO",192,68),("ART",128,64),("BAND",128,104),("DRAMA",64,84),("CHEMISTRY",64,64),("GO HOME",128,84)];let mut ranges=Vec::new();
  for(name,x,y)in entries{let cell=Cell{x,y,width:64,height:20};ensure!(read_indexed_cell_in_prefix(&before,0,cell)?==read_indexed_cell_in_prefix(&source,0,cell)?,"club cell already changed: {name}");let p=canvas(font,name,64,20,1,15)?;ranges.extend(write_indexed_cell_in_prefix(&mut after,0,cell,&p)?);for phase in [4usize,5]{let pal=read_4bpp_palette_words_in_prefix(&before,0,phase)?;rgba_png(&out.join(format!("club-{}-palette{phase}-v23.png",name.to_lowercase().replace(' ',"-"))),&p,64,20,&pal)?;}}
  ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|i>=r[0]&&i<r[1])),"header change outside club cells");let profile=crate::paged_compression::source_paged_compression_profile(current)?;let mut stored=crate::paged_compression::compress_page_safe_image_in_slot(&after,profile,current.len())?;let length=stored.len();ensure!(decompress(&stored,false)?==after,"header roundtrip");stored.resize(current.len(),0);ensure!(decompress(&stored,true)?==after,"padded header roundtrip");let patched_hash=sha256_bytes(&stored);Ok((stored,json!({"labels":entries.map(|e|e.0),"compressed_bytes":length,"fixed_slot":current.len(),"all_other_header_bytes_preserved":true,"native_palettes_and_club_consumer_preserved":true,"input_sha256":sha256_bytes(current),"patched_sha256":patched_hash})))
 }
 fn patch_locations(current:&[u8],original:&[u8],font:&fontdue::Font,out:&Path)->Result<(Vec<u8>,Value)>{
  ensure!(sha256_bytes(original)=="7fe06a64a164abd70fe71d0ddf2e6e93ff43b6accd0ffd779f1f61128d5e3ebc","original graphics identity");let slots=crate::tzz::parse_tzz(current)?;ensure!(slots==crate::tzz::parse_tzz(original)?,"graphics table differs");let slot=slots[3];let stored=&current[slot.compressed_range()];let before=decompress(stored,true)?;let src=decompress(&original[slot.compressed_range()],true)?;let off=0xf800;let tim=crate::embedded_tim::parse_embedded_tim_at(&before,off)?;ensure!(tim.bits_per_pixel==8&&tim.pixel_width==256&&tim.pixel_height==244,"secondary location TIM geometry");let end=off+tim.total_size;
  ensure!(before[off..end]==src[off..end]&&sha256_bytes(&src[off..end])=="986dd8a53fd8fb51ccf8dd603262badde1b06bb39b00f060a21b71ffe7a3e053","Club Building secondary TIM source mismatch");let pal=read_8bpp_palette_words_in_prefix(&before,off,0)?;let text=canvas(font,"CLUB BUILDING",76,22,nearest(&pal,[255,255,255]),nearest(&pal,[25,25,25]))?;let mut label=vec![0u8;128*24];for y in 0..22{label[(y+1)*128+4..(y+1)*128+80].copy_from_slice(&text[y*76..y*76+76]);}let mut after=before.clone();let ranges=write_8bpp_indexed_cell_in_prefix(&mut after,off,Cell{x:0,y:220,width:128,height:24},&label)?;ensure!(before.iter().zip(&after).enumerate().all(|(i,(a,b))|a==b||ranges.iter().any(|r|i>=r[0]&&i<r[1])),"location change outside strip");rgba_png(&out.join("club-building-secondary-v23.png"),&label,128,24,&pal)?;
  let profile=crate::paged_compression::source_paged_compression_profile(stored)?;let prefix=before.iter().zip(&after).take_while(|(a,b)|a==b).count()&!1;let(encoded,kept)=crate::paged_compression::compress_on_source_final_page_with_preserved_prefix(&after,stored,profile,prefix)?;let new=crate::paged_compression::source_paged_compression_profile(&encoded)?;ensure!((new.stream_byte_count-1)/0x800==(profile.stream_byte_count-1)/0x800&&new.maximum_match_words<=profile.maximum_match_words&&new.maximum_control_block_output_words<=profile.maximum_control_block_output_words&&kept.encoded_byte_count>0,"native graphics compression contract");ensure!(encoded.len()<=slot.compressed_size,"secondary location exceeds compressed slot");ensure!(decompress(&encoded,false)?==after,"location roundtrip");let length=encoded.len();let mut padded=encoded;padded.resize(slot.compressed_size,0);ensure!(decompress(&padded,true)?==after,"padded location roundtrip");let mut archive=current.to_vec();archive[slot.compressed_range()].copy_from_slice(&padded);ensure!(crate::tzz::parse_tzz(&archive)?==slots,"graphics table changed");ensure!(archive[..slot.offset]==current[..slot.offset]&&archive[slot.offset+slot.compressed_size..]==current[slot.offset+slot.compressed_size..],"other graphics members changed");Ok((archive,json!({"label":"CLUB BUILDING","member":3,"tim_offset":off,"compressed_bytes":length,"fixed_slot":slot.compressed_size,"first_tim_and_other_members_preserved":true,"all_other_pixels_and_palettes_preserved":true})))
 }
 fn run()->Result<()>{
  let master=PathBuf::from(std::env::var("JG2_V23_MASTER")?);let source=PathBuf::from(std::env::var("JG2_V23_SOURCE")?);let out=PathBuf::from(std::env::var("JG2_V23_OUTPUT")?);ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"disc identity mismatch");ensure!(!out.exists(),"output directory exists");fs::create_dir_all(&out)?;
  let font_bytes=fs::read(std::env::var("JG2_V23_FONT")?)?;let font=fontdue::Font::from_bytes(font_bytes.clone(),fontdue::FontSettings::default()).map_err(|e|anyhow::anyhow!("font: {e}"))?;
  let text_before=rebuild::read_record(&master,DIALOGUE)?.1;let bundle_before=rebuild::read_record(&master,BUNDLE)?.1;let graphic_before=rebuild::read_record(&master,GRAPHICS)?.1;let header_before=rebuild::read_record(&master,HEADER)?.1;let game_before=rebuild::read_record(&master,MGAME)?.1;
  let original_graphics=rebuild::read_record(&source,GRAPHICS)?.1;let original_header=rebuild::read_record(&source,HEADER)?.1;let original_game=rebuild::read_record(&source,MGAME)?.1;assert_pointer_consumer(&game_before,&original_game)?;
  let(text,decoded,text_report)=patch_text(&text_before,&font)?;let mut bundle=bundle_before.clone();let slots=crate::tzz::parse_tzz(&bundle)?;ensure!(slots.len()==5&&bundle[slots[0].compressed_range()]==text_before,"Taiyo bundle binding");bundle[slots[0].compressed_range()].copy_from_slice(&text);ensure!(bundle[..slots[0].offset]==bundle_before[..slots[0].offset]&&bundle[slots[0].offset+slots[0].compressed_size..]==bundle_before[slots[0].offset+slots[0].compressed_size..],"other school dialogue changed");
  let(graphic,graphics_report)=patch_locations(&graphic_before,&original_graphics,&font,&out)?;let(header,header_report)=patch_header(&header_before,&original_header,&game_before,&font,&out)?;
  let bin=out.join("justice-gakuen2-club-join-v23.bin");let replacements=[rebuild::FixedRecordReplacement{path:DIALOGUE,data:&text},rebuild::FixedRecordReplacement{path:BUNDLE,data:&bundle},rebuild::FixedRecordReplacement{path:GRAPHICS,data:&graphic},rebuild::FixedRecordReplacement{path:HEADER,data:&header}];let replaced=rebuild::copy_and_replace_records(&master,&bin,&replacements)?;
  for r in &replacements{ensure!(rebuild::read_record(&bin,r.path)?.1==r.data,"record readback failed");}let allowed=replaced.iter().flat_map(|r|r.target_lbas.iter().copied()).collect::<BTreeSet<_>>();let(changed,hash)=rebuild::compare_and_hash_images(&master,&bin)?;ensure!(!changed.is_empty()&&changed.iter().all(|l|allowed.contains(l)),"changed sectors outside owned records");let mut track=crate::disc::RawTrack::open(&bin)?;for l in &changed{ensure!(crate::disc::mode2::verify(&track.raw_sector(*l)?),"sector checksum failed");}ensure!(sha256_file(&master)?==MASTER_HASH&&sha256_file(&source)?==SOURCE_HASH,"input changed");
  let cue=bin.with_extension("cue");fs::write(&cue,"FILE \"justice-gakuen2-club-join-v23.bin\" BINARY\r\n  TRACK 01 MODE2/2352\r\n    INDEX 01 00:00:00\r\n")?;
  if std::env::var("JG2_V23_QA_EXPORT").is_ok(){fs::write(out.join("MGG04T-v23-private.decoded"),decoded)?;}
  let report=json!({"kind":"Taiyo complete April club joining English v23","source_sha256":SOURCE_HASH,"master_sha256":MASTER_HASH,"output_sha256":hash,"font_sha256":sha256_bytes(&font_bytes),"changed_sector_count":changed.len(),"cue":cue.display().to_string(),"text":text_report,"graphics":graphics_report,"header":header_report,"mgame_preserved":true,"earlier_and_untargeted_layers_preserved":true,"other_schools_dialogue_preserved":true,"native_pointer_consumer_verified":true});fs::write(out.join("club-join-v23-report.json"),serde_json::to_vec_pretty(&report)?)?;eprintln!("POOL_CLUB_V23_COMPLETE=1\nOUTPUT_SHA256={hash}\nCHANGED_RAW_SECTORS={}\nCUE={}\n{}",changed.len(),cue.display(),serde_json::to_string_pretty(&report)?);Ok(())
 }
 #[test] fn english_project_club_join_v23()->Result<()>{std::thread::Builder::new().stack_size(64*1024*1024).spawn(run)?.join().unwrap()}
 #[test] fn club_join_v23_shared_pointer_roundtrip()->Result<()>{let a=bytes(vec![1,0x3001]);let b=bytes(vec![2,0x3003,0x3001,3,0x3001]);let expected=vec![(0,vec![a.clone(),b.clone(),a.clone()]),(1,vec![b.clone(),a])];let mut d=vec![0u8;0x51800];let(_,aliases)=compact(&mut d,&expected)?;ensure!(aliases==3&&pointer_banks(&d)?==expected,"alias roundtrip");let p=u32_at(&d,ARENA)? as usize-0x800d0000;d[p..p+4].copy_from_slice(&0x800d0000u32.to_le_bytes());ensure!(pointer_banks(&d).is_err(),"invalid pointer accepted");Ok(())}
}

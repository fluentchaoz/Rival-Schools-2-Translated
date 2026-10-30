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

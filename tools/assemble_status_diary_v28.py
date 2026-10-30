"""Assemble standalone v28; private translations remain runtime inputs."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1];s=(r/'build_daily_map_english_v27.ps1').read_text();pre,b=s.split("$Rust = @'\n",1);_,post=b.split("\n'@",1)
def update(s):
 return s.replace('v27','v28').replace('V27','V28').replace('v26','v27').replace('daily-map-v28','status-diary-v28').replace('daily_map_v28','status_diary_v28').replace('DAILY_MAP_V28','STATUS_DIARY_V28').replace('shared-dates-v27','daily-map-v27').replace('DAILY MAP, HELP AND NAME DEFAULTS','STATUS AND DIARY').replace('JG2-Daily-Map-v28-Inputs','JG2-Status-Diary-v28-Inputs').replace('1a1f3ec2f5ab6abf4730748fd68df9e30cc8db55e43bc85308593986932a1e45','3f5b7630fd3115804c892e75c37213fbfff148b28ed657d0424ecba0614dc34e')
pre=update(pre);post=update(post);rust=(r/'patches/status_diary_v28.rs').read_text();h=re.search(r'const PACKET_HASH:&str="([0-9a-f]{64})"',rust)[1];pre=re.sub(r'\$ExpectedPacketHash = "[a-f0-9]+"',f'$ExpectedPacketHash = "{h}"',pre)
post=post.replace('Building daily/map help, map labels, and new-enrollment defaults...','Building status labels, 57 item descriptions and diary choices...').replace('$Report.source_patterns -ne 21','$Report.source_patterns -ne 57').replace('$Report.source_help_coordinates -ne 1638','$Report.source_item_coordinates -ne 4446').replace(') -ne 1638',') -ne 4446').replace('-or $Report.map_copies -ne 11 -or $Report.map_label_rectangles -ne 66 -or -not $Report.default_names.existing_saved_names_unchanged','-or $Report.graphics_labels -ne 40 -or -not $Report.birthday_layout.code_bytes_and_saved_records_preserved')
a=post.index('Write-Host ("Translated daily/map');post=post[:a]+'''Write-Host ("Translated item-description coordinates: " + $Report.translated_coordinates)
Write-Host ("Custom existing payloads retained: " + $Report.custom_coordinates_preserved)
Write-Host "57 status item descriptions across 78 banks; 40 shared graphics labels."
Write-Host "Status: headings, 19 character names, M/F and BIRTHDAY MM/DD."
Write-Host "Diary: main choices, speed settings and Japanese practice labels."
Write-Host "Earlier English, saved names, birthday values, relationships and item effects preserved."
Write-Host ("Previews: " + (Join-Path $BuildDir "previews"))
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v27. Fresh-boot this CUE and check Status and Diary, speed choices and practice names."
Write-Host "If you own an item, check its description. Save/load prompts and story dialogue remain outside this batch."
'''
(r/'build_status_diary_english_v28.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

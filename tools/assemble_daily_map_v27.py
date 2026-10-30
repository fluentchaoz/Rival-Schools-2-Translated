"""Build the public standalone v27 wrapper; private translations are runtime inputs."""
from pathlib import Path
import re
r=Path(__file__).resolve().parents[1];s=(r/'build_shared_dates_english_v26.ps1').read_text();pre,b=s.split("$Rust = @'\n",1);_,post=b.split("\n'@",1)
def update(t):
 return t.replace('v26','v27').replace('V26','V27').replace('v25','v26').replace('shared-dates-v27','daily-map-v27').replace('shared_dates_v27','daily_map_v27').replace('SHARED_DATES_V27','DAILY_MAP_V27').replace('locations-names-v26','shared-dates-v26').replace('SHARED DATES AND DAILY NARRATION','DAILY MAP, HELP AND NAME DEFAULTS').replace('shared_daily_dates_v27.json','daily_map_v27.json').replace('JG2-Shared-Dates-v27-Inputs','JG2-Daily-Map-v27-Inputs').replace('5f31d90f089f520d6824add5c5368e10be2607955ad3b9e5c24b73b9aa010453','1a1f3ec2f5ab6abf4730748fd68df9e30cc8db55e43bc85308593986932a1e45')
pre=update(pre);post=update(post);rust=(r/'patches/daily_map_v27.rs').read_text();h=re.search(r'const PACKET_HASH:&str="([0-9a-f]{64})"',rust)[1];pre=re.sub(r'\$ExpectedPacketHash = "[a-f0-9]+"',f'$ExpectedPacketHash = "{h}"',pre)
post=post.replace('Building shared dates and daily narration across 78 text banks...','Building daily/map help, map labels, and new-enrollment defaults...')
post=post.replace('$Report.source_patterns -ne 46','$Report.source_patterns -ne 21').replace('$Report.source_date_coordinates -ne 4836','$Report.source_help_coordinates -ne 1638').replace(') -ne 4836',') -ne 1638').replace('$Report.all_other_payloads_and_non_text_records_preserved','$Report.all_untargeted_payloads_records_and_saved_names_preserved')
post=post.replace('-or $Report.packet_sha256 -ne $ExpectedPacketHash','-or $Report.packet_sha256 -ne $ExpectedPacketHash -or $Report.map_copies -ne 11 -or $Report.map_label_rectangles -ne 66 -or -not $Report.default_names.existing_saved_names_unchanged')
a=post.index('Write-Host ("Translated date/narration');post=post[:a]+'''Write-Host ("Translated daily/map help coordinates: " + $Report.translated_coordinates)
Write-Host ("Custom existing payloads retained: " + $Report.custom_coordinates_preserved)
Write-Host "Reviewed help scope: 21 patterns across 78 School Life text banks."
Write-Host "Map label atlases: 11 copies / 66 labels; thumbnails, cursor, frames and palettes preserved."
Write-Host "New-enrollment defaults are in English; existing saved names remain unchanged."
Write-Host ("Native glyph/map previews: " + (Join-Path $BuildDir "previews"))
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v26. Fresh-boot this new CUE and check all six map destinations and their help text."
Write-Host "Name defaults apply to new enrollments with empty fields; your current saved name is preserved."
Write-Host "Unique story dialogue and save/load prompts remain outside this batch."
'''
(r/'build_daily_map_english_v27.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post);print('Standalone v27 wrapper assembled; private packet not embedded')

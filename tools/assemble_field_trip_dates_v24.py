from pathlib import Path
r=Path(__file__).resolve().parents[1];s=(r/'build_club_join_english_v23.ps1').read_text();pre,b=s.split("$Rust = @'\n",1);_,post=b.split("\n'@",1)
def update(s):return s.replace('v23','v24').replace('V23','V24').replace('v22','v23').replace('club-join-v24','field-trip-dates-v24').replace('club_join_v24','field_trip_dates_v24').replace('CLUB_JOIN_V24','FIELD_TRIP_V24').replace('pool-club-v23','club-join-v23').replace('CLUB JOINING','FIELD TRIP AND DATES').replace('b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e','9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1')
pre=update(pre);post=update(post);post=post.replace(',$Preview','');a=post.index('if ($Report.text.translated_story_entries');b=post.index('\nif ((Get-Item',a);post=post[:a]+'if ($Report.story_messages -ne 430 -or $Report.date_messages -ne 1550) { throw "Final report scope verification failed." }'+post[b:];a=post.index('Write-Host ("Dialogue compressed bytes:');post=post[:a]+'''Write-Host "430 field-trip messages across both player variants; 1550 event-bank date formats."
Write-Host ("Event title copies patched: " + $Report.title_copies_patched)
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v23. Boot this new CUE fresh and test April 16, its opening date, and all field-trip choices."
Write-Host "Other schools' story dialogue and later story events remain untranslated."
''';rust=(r/'patches/field_trip_dates_v24.rs').read_text().replace('PACKET_REPLACE',(r/'translations/field_trip_taiyo_v24.json').read_text());(r/'build_field_trip_dates_english_v24.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

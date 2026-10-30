from pathlib import Path
r=Path(__file__).resolve().parents[1];s=(r/'build_field_trip_dates_english_v24.ps1').read_text();pre,b=s.split("$Rust = @'\n",1);_,post=b.split("\n'@",1)
def update(s):return s.replace('v24','v25').replace('V24','V25').replace('v23','v24').replace('field-trip-dates-v25','locations-names-v25').replace('field_trip_dates_v25','locations_names_v25').replace('FIELD_TRIP_V25','LOCATIONS_NAMES_V25').replace('club-join-v24','field-trip-dates-v24').replace('FIELD TRIP AND DATES','LOCATIONS AND NAME INSERTIONS').replace('9329e5a8ed0c1270fa090f015a4a833ee4b00f120ec884b3f079d67d619fd4f1','c21d3d0a6ffdfc3d4a666251f450edbc5b68f16b90716101143d2c69e2415e4f')
pre=update(pre).replace('Building the pool/club dialogue, daily menu, and location labels...','Building English name insertions and matching location labels...');post=update(post);post=post.replace('$Report.story_messages -ne 430 -or $Report.date_messages -ne 1550','$Report.honorific_entries -ne 100 -or $Report.event_banks -ne 25 -or -not $Report.name_selection_and_enrolled_names_preserved');a=post.index('Write-Host "430 field-trip');post=post[:a]+'''Write-Host "100 honorific insertion strings localized across 25 event banks."
Write-Host "Enrolled names and relationship-based name selection preserved."
Write-Host "Matching location labels translated; existing English strips preserved."
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v24. Boot the new CUE fresh and check School Gate, Plaza, and Hinata/Ran addressing your name."
Write-Host "Unmatched location graphics and other scene banks may still contain Japanese."
''';rust=(r/'patches/locations_names_v25.rs').read_text();(r/'build_locations_names_english_v25.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

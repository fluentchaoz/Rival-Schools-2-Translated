"""Regenerate the self-contained v21 wrapper from its reviewed Rust/English sources."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'build_rating_popup_english_v20.ps1').read_text()
a=s.index("$Rust = @'\n");b=s.index("\n'@",a)+3
rust=(root/'patches/entrance_ceremony_v21.rs').read_text().replace('PACKET_REPLACE',(root/'translations/entrance_ceremony_taiyo_v21.json').read_text())
s=s[:a]+"$Rust = @'\n"+rust+"\n'@"+s[b:]
pre,r=s.split("$Rust = @'\n",1);rust,post=r.split("\n'@",1)
def change(x):
 return x.replace('v20','v21').replace('V20','V21').replace('v19','v20').replace('rating-popup-v21','entrance-ceremony-v21').replace('rating_popup_v21','entrance_ceremony_v21').replace('RATING_POPUP_V21','ENTRANCE_CEREMONY_V21').replace('RATING POPUP','ENTRANCE CEREMONY').replace('classroom-label-v20','rating-popup-v20').replace('0b378dd421323c6248307013ef185270ea581964d34cd7ab52826eb8b6e412f2','bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec').replace('src/diary_scene/runtime_bundle_build.rs','src/dialogue_audit/name_entry_input_tests.rs').replace('runtime_bundle_build.pre-v21','name_entry_input_tests.pre-v21').replace('Building the English RATING UP popup and verifying the candidate...','Building the Taiyo entrance ceremony and verifying the candidate...')
pre=change(pre);post=change(post)
post=post.replace('$Preview = Join-Path $BuildDir "entrance-ceremony-v21-preview.png"','$Preview = Join-Path $BuildDir "entrance-title-v21.png"')
a=post.index('if ($Report.english_text');b=post.index('\nif ((Get-Item',a)
post=post[:a]+'if ($Report.text.translated_dialogue_entries -ne 114 -or $Report.text.translated_date_entries -ne 4 -or -not $Report.earlier_layers_preserved -or -not $Report.other_schools_dialogue_preserved) { throw "Final report scope verification failed." }'+post[b:]
a=post.index('Write-Host ("Quiz member compressed');post=post[:a]+'''Write-Host ("Dialogue compressed bytes: {0} / {1}" -f $Report.text.compressed_bytes,$Report.text.fixed_slot)
Write-Host "114 dialogue entries + 4 dynamic date messages translated. Both player variants and both ceremony choices covered."
Write-Host "APRIL 8 / ENTRANCE CEREMONY, SCHOOL GATE, and GYM graphics installed."
Write-Host "Earlier quiz, enrollment, classroom and stat layers preserved."
Write-Host ""
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("TITLE PREVIEW: " + $Preview)
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v20. Boot the new CUE fresh, complete the quiz, then check the full Taiyo entrance ceremony and both choices."
Write-Host "The following club-orientation events and other schools' ceremony dialogue remain untranslated."
'''
(root/'build_entrance_ceremony_english_v21.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

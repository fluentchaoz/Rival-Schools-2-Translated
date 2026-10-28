"""Regenerate the standalone Windows builder without requiring Python on Windows."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'build_entrance_ceremony_english_v21.ps1').read_text();pre,r=s.split("$Rust = @'\n",1);_,post=r.split("\n'@",1)
def update(s):
 return s.replace('v21','v22').replace('V21','V22').replace('v20','v21').replace('entrance-ceremony-v22','pool-club-v22').replace('entrance_ceremony_v22','pool_club_v22').replace('ENTRANCE_CEREMONY_V22','POOL_CLUB_V22').replace('ENTRANCE CEREMONY','POOL AND CLUB').replace('rating-popup-v21','entrance-ceremony-v21').replace('bf79b70fb5d806669fbf48917c634920e1934ff63d82072b9a0a48ab63238fec','f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0').replace('Building the Taiyo entrance ceremony and verifying the candidate...','Building the pool/club dialogue, daily menu, and location labels...')
pre=update(pre);post=update(post)
post=post.replace('$Preview = Join-Path $BuildDir "entrance-title-v22.png"','$Preview = Join-Path $BuildDir "menu-continue-palette4-v22.png"')
a=post.index('if ($Report.text.translated_dialogue_entries');b=post.index('\nif ((Get-Item',a)
post=post[:a]+'if ($Report.text.translated_story_entries -ne 240 -or $Report.text.translated_menu_help_entries -ne 4 -or -not $Report.earlier_and_untargeted_layers_preserved -or -not $Report.other_schools_dialogue_preserved -or -not $Report.native_pointer_consumer_verified) { throw "Final report scope verification failed." }'+post[b:]
a=post.index('Write-Host ("Dialogue compressed bytes:');post=post[:a]+'''Write-Host ("Dialogue compressed bytes: {0} / {1}" -f $Report.text.compressed_bytes,$Report.text.fixed_slot)
Write-Host ("Shared text arena: {0} / {1} bytes; {2} duplicate message references shared." -f $Report.text.arena_used_bytes,$Report.text.arena_capacity_bytes,$Report.text.shared_message_references)
Write-Host "240 pool/club/tutorial dialogue entries + 4 Taiyo daily-menu help messages translated."
Write-Host "Daily labels: CONTINUE / MOVE / STATUS / DIARY. Both player variants and all eight club descriptions covered."
Write-Host "Walkway, Poolside, Club Building, Field, Sumo Room, Gym, and Classroom labels updated where their exact source graphics match."
Write-Host "Earlier and untargeted payloads, graphics, and other school dialogue preserved."
Write-Host ""
Write-Host ("CUE TO TEST: " + $OutputCue) -ForegroundColor Yellow
Write-Host ("MENU PREVIEW: " + $Preview)
Write-Host ("REPORT: " + $ReportPath)
Write-Host "Keep v21. Boot the new CUE fresh, test the daily menu and pool-to-club sequence, including choice columns and the training tutorial."
Write-Host "Later April scenes, menu help in other text banks, and other schools' dialogue remain outside this patch."
'''
rust=(root/'patches/pool_club_v22.rs').read_text().replace('PACKET_REPLACE',(root/'translations/pool_club_v22.json').read_text())
(root/'build_pool_club_english_v22.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'build_pool_club_english_v22.ps1').read_text();pre,body=s.split("$Rust = @'\n",1);_,post=body.split("\n'@",1)
def update(s):
 return s.replace('v22','v23').replace('V22','V23').replace('v21','v22').replace('pool-club-v23','club-join-v23').replace('pool_club_v23','club_join_v23').replace('POOL_CLUB_V23','CLUB_JOIN_V23').replace('entrance-ceremony-v22','pool-club-v22').replace('POOL AND CLUB','CLUB JOINING').replace('f4a470836cded402c5ec5df041f0023693099761f1a25cd1045690d8bae005f0','b21934066fc21a217ce5c37772abd53b81e881706d685bd10dc349cc0f8be95e')
pre=update(pre).replace('Building the pool/club dialogue, daily menu, and location labels...','Building the remaining club tutorials and club labels...');post=update(post)
post=post.replace('menu-continue-palette4-v23.png','club-baseball-palette4-v23.png')
a=post.index('if ($Report.text.translated_story_entries');b=post.index('\nif ((Get-Item',a)
post=post[:a]+'if ($Report.text.translated_story_entries -ne 342 -or -not $Report.earlier_and_untargeted_layers_preserved -or -not $Report.other_schools_dialogue_preserved -or -not $Report.native_pointer_consumer_verified -or -not $Report.mgame_preserved) { throw "Final report scope verification failed." }'+post[b:]
a=post.index('Write-Host "240');b=post.index('Write-Host ""',a)
post=post[:a]+'''Write-Host "342 remaining club joining/tutorial entries translated, both player variants."
Write-Host "All eight clubs and go-home covered, including skip/repeat tutorial choices."
Write-Host "Nine club HUD names and the secondary Club Building location label updated."
'''+post[b:]
post=post.replace('MENU PREVIEW:','CLUB PREVIEW:').replace('test the daily menu and pool-to-club sequence, including choice columns and the training tutorial.','test the Club Building label, join baseball, check its HUD name, and finish the tutorial.').replace("Later April scenes, menu help in other text banks, and other schools' dialogue remain outside this patch.","The later field trip and other schools remain outside this patch.")
rust=(r/'patches/club_join_v23.rs').read_text().replace('PACKET_REPLACE',(r/'translations/club_join_v23.json').read_text())
(r/'build_club_join_english_v23.ps1').write_text(pre+"$Rust = @'\n"+rust+"\n'@"+post)

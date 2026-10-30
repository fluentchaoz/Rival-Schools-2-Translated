"""Build reviewed field-trip packet from the English draft and control manifest."""
from pathlib import Path
import json,textwrap,re
r=Path(__file__).resolve().parents[1];p=json.loads((r/'translations/field_trip_taiyo_v24.draft.json').read_text());review=json.loads((r/'validation/field-trip-v24-review.json').read_text());entries={e['index']:e['text']for e in p['entries']}
fix={349:"HEY, {0}!\nGLAD THE WEATHER\nCLEARED UP.",352:"MORNING, {0}!\nI'M EXCITED ABOUT\nTODAY'S TRIP!",361:"FERRIS WHEEL? SURE.\nWHAT ABOUT YOU,\n{0}?",365:"{0},\nSEE YOU LATER!",366:"OH, {0}!\nWHAT ARE YOU DOING\nHERE?",395:"GOOD POINT.\n{0}, LET'S GO!",403:"THAT'S IT!\n{0}, COME ALONG!",430:"HEY, {0}!\nLOOK AT THIS LINE.",450:"{0}, WE NEVER GOT\nTO RIDE THE WHEEL!\nWE WAITED SO LONG.\nI WAS SO EXCITED!",454:"HINATA, HOW ABOUT\n{0} AND I BUY YOU\nCAKE TO MAKE UP?",460:"{0}, OUR TURN!\nYOU CAME TO RIDE,\nRIGHT? LET'S GO!",468:"PLEASE, {0}!\nGIVE MY HELMET BACK!",471:"{0}, HOW AWFUL.\nI'M SCARED OF\nCOASTERS. THAT'S WHY\nI WANTED MY HELMET.",488:"OH? ISN'T THAT\n{0}?",489:"{0}! WHAT ARE\nYOU DOING HERE?",507:"{0}, NO GUT!",508:"{0}, YOU MEAN\nGUTS. ARE YOU REALLY\nNOT COMING?",512:"HEY, {0}!\nYOU CAME HERE, TOO?",525:"HAHA! PRACTICE.\nRIGHT, {0}?",537:"...{0}?\nAS YOU CAN SEE.",557:"{0}...\nNATURE IS A FINE\nTHING."}
entries.update(fix)
controls={(e['selector'],e['entry']):e['controls']for e in review['protected_control_coordinates']}
for e in review['protected_control_coordinates']:
 if e['selector']!=0:continue
 i=e['entry'];cs=e['controls']
 if cs[0][0]in [0x3002,0x3003]:entries[i]='{0}'+entries[i]+'{1}'
 else:assert '{0}'in entries[i],i
# Native two-column 4-option choice: right column begins at cell ten.
entries[380]='WHEEL     COASTER\nHAUNTED   ARCADE\nWALK'
entries[388]='FERRIS WHEEL?\nROLLER COASTER?\nHOW ABOUT THE POND?'
overrides={'1:498':'EEK! SOMETHING COLD\nTOUCHED MY NECK!','1:499':"I-IT WASN'T ME! OW!\nTIFFANY, PLEASE STOP\nFLAILING AROUND!",'1:513':"I JUST GOT HERE.\nARE YOU ALL HAVING\nFUN?"}
for s in [0,1]:
 for i in range(348,563):
  t=overrides.get(f'{s}:{i}',entries[i]);cs=controls.get((s,i),[]);ids=[int(x)for x in re.findall(r'\{(\d+)\}',t)];assert ids==list(range(len(cs))),(s,i,ids,cs)
  vis=t
  for j,c in enumerate(cs):vis=vis.replace('{'+str(j)+'}','OOOOOO'if 0x2000<=c[0]<=0x2009 else'')
  assert len(vis.splitlines())<=4 and all(len(l)<=20 for l in vis.splitlines()),(s,i,vis)
packet={'record':p['record'],'selectors':[0,1],'entries':[{'index':i,'text':entries[i]}for i in sorted(entries)],'overrides':overrides,'review':{'male_source_messages':215,'variant_payload_differences_reviewed':96,'protected_control_coordinates':64,'source_control_order_preserved':True,'maximum_name_cells':6,'choice_geometry_requires_native_test':True}}
(r/'translations/field_trip_taiyo_v24.json').write_text(json.dumps(packet,indent=2)+'\n');print('430 messages: source controls and six-cell name bounds validated.')

"""Generate assets/infirmary_v42.json: English for the Infirmary event (MGM04 selectors 0/1, entries 171-188).
Usage: python make_infirmary_spec_v42.py <v41.bin> <output.json>"""
import json,sys
from pathlib import Path
from practice_disc_v30 import Disc,decode,sha
from backup_text_v36 import banks
HAYATO,KYOKO='MR. HAYATO','MS. KYOKO'
# index: text (same for both player variants) or (male text, female text)
TEXT={
171:"PLEASE THINK ABOUT\nTHE STUDENTS' BODIES\nA LITTLE WHEN YOU\nCOACH THEM.",
172:"THESE DAYS EVERY\nSTUDENT LACKS THE\nSTAMINA! WE HAVE TO\nTRAIN THEM HARDER!",
173:"THIS SOUNDS SERIOUS.\nWHAT SHOULD I DO?",
174:"JOIN THE TALK\nGO ELSEWHERE",
175:"I'LL TRY JOINING IN.\n...THAT'S RIGHT.\nI DEFINITELY AGREE.",
176:"RIGHT?!\n...WAIT, WHO ARE YOU\nNODDING ALONG WITH?",
177:f"{HAYATO}\n{KYOKO}",
178:f"I AGREE WITH\n{HAYATO}.",
179:("YOU GET IT, {0}!\nBOYS SHOULD BE LIKE\nTHAT, AFTER ALL!","YOU GET IT, {0}!\nEVEN GIRLS NEED TO\nTRAIN, YOU KNOW!"),
180:"ALL RIGHT, THEN!\nLET'S HIT THE FIELD\nFOR SOME TRAINING!\nGET OUTSIDE!",
181:("R-RIGHT NOW?!\nHOLD ON A SECOND...\nI SHOULDN'T HAVE\nSAID ANYTHING.","R-RIGHT NOW?!\nHOLD ON A SECOND...\nI SHOULDN'T HAVE\nSAID ANYTHING..."),
182:f"OF COURSE, I THINK\n{KYOKO}'S OPINION\nIS THE RIGHT ONE.",
183:"AS EXPECTED, {0}{1}{2}.\nYOU GET IT. BUT\nSTUDENT STAMINA IS\nFALLING EVERY YEAR.",
184:"YES.",
185:"SO LET ME GIVE YOUR\nBODY A LITTLE\nCORRECTION.",
186:"THERE, DOESN'T YOUR\nBODY FEEL LIGHTER?\nI'LL LOOK AFTER YOU\nWHEN IT FEELS HEAVY.",
187:f"THANK YOU.\nTHANKS TO {KYOKO},\nMY BODY FEELS LIGHT.\nI'M GLAD.",
188:"I'D BETTER NOT GET\nCAUGHT IN THIS.\nI'LL GO SOMEWHERE\nELSE. WHERE TO?",
}
def build(bin_path):
    d=Disc(bin_path);before=decode(d.record('DAT2/MGM04.BIZ'))[0];bs=banks(before);entries=[]
    for sel in (0,1):
        for i,t in TEXT.items():
            text=t[sel] if isinstance(t,tuple) else t
            for line in text.split('\n'):
                if len(line.replace('{0}','').replace('{1}','').replace('{2}',''))>20:raise ValueError('line too long: '+line)
            if len(text.split('\n'))>4:raise ValueError('too many lines')
            entries.append(dict(selector=sel,index=i,source_payload_sha256=sha(bs[sel][i]),text=text))
    return dict(path='DAT2/MGM04.BIZ',source_decoded_sha256=sha(before),event='Infirmary: Hayato and Kyoko disagree about student training',entries=entries)
if __name__=='__main__':
    spec=build(Path(sys.argv[1]));Path(sys.argv[2]).write_text(json.dumps(spec,indent=2)+'\n');print(len(spec['entries']),'entries',spec['source_decoded_sha256'])

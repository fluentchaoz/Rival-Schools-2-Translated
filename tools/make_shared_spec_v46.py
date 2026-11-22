"""Generate assets/shared_v46.json from assets/shared/tr_*.txt.
Usage: python make_shared_spec_v46.py <original.bin> <v45.bin> <patterns.pkl> <groups.pkl> <output.json>"""
import json,pickle,sys
from pathlib import Path
from practice_disc_v30 import Disc,decode,sha
from backup_text_v36 import banks
from shared_v46 import load_translations,signature
import inspect_pool_club_v22 as I
ROOT=Path(__file__).resolve().parents[1]
def main(orig,cur,pat,grp,out):
    o=Disc(Path(orig));n=Disc(Path(cur));order=pickle.load(open(pat,'rb'));glist,_=pickle.load(open(grp,'rb'))
    tr=load_translations(ROOT/'assets/shared');sigtext={}
    for h,ns in glist:
        text=next((tr[x] for x in ns if x in tr),None)
        if text is None:continue
        for x in ns:sigtext[order[x][0]]=text
    spec={};total=0
    for k in o.records:
        if not(k.startswith('DAT2/MG')and k.endswith('.BIZ')):continue
        try:bo=decode(o.record(k))[0];bn=decode(n.record(k))[0]
        except Exception:continue
        if len(bo)<0x31020:continue
        try:ko={(s,i):w for s,i,w in I.banks(bo)};kn={(s,i):w for s,i,w in I.banks(bn)};bsn=banks(bn)
        except Exception:continue
        entries=[]
        for (s,i),w in sorted(ko.items()):
            if s in(0,1):continue
            if tuple(kn.get((s,i),()))!=tuple(w):continue
            text=sigtext.get(signature(bo,list(w)))
            if text is None:continue
            entries.append(dict(selector=s,index=i,source_payload_sha256=sha(bsn[s][i]),text=text))
        if k=='DAT2/MGM04.BIZ':
            import make_classroom_spec_v44 as C
            have={(e['selector'],e['index']) for e in entries}
            for e in C.build(Path(cur))['entries']:
                if (e['selector'],e['index']) not in have:entries.append(e)
        if entries:spec[k]=dict(source_decoded_sha256=sha(bn),entries=entries);total+=len(entries)
    Path(out).write_text(json.dumps(spec,indent=1)+'\n');print(len(spec),'records',total,'entries')
if __name__=='__main__':main(*sys.argv[1:])

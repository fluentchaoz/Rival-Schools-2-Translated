import sys,glob,pickle,collections,hashlib
sys.path.insert(0,r'C:\Users\Fluent\JG2-Project\repo\tools')
from practice_disc_v30 import Disc,decode
import inspect_pool_club_v22 as I
S=r'C:\Users\Fluent\AppData\Local\Temp\claude\64d96de68a049de7\e3f69e87-1127-44ee-8609-cdd731c4a651\scratchpad'
o=Disc(glob.glob(r'C:\Users\Fluent\JG2-Project\1-KEEP\original-disc\*.bin')[0])
n=Disc(r'C:\Users\Fluent\JG2-Project\1-KEEP\v45-CURRENT-play-this\justice-gakuen2-calendar-v45.bin')
ref=decode(o.record('DAT2/MGC01.BIZ'))[0]
canon={c:707+i for i,c in enumerate('ABCDEFGHIJKLMNOPRSTUVWXYQZ')};canon.update({'!':701,"'":702,',':703,'-':704,'.':705,'/':706,'?':66})
ENG={ref[384+v*200:384+(v+1)*200] for v in canon.values()}|{bytes(200)}
stat=collections.defaultdict(lambda:collections.Counter());uniq=collections.defaultdict(set);rec_jp=collections.Counter();rec_tot=collections.Counter()
for k in o.records:
    if not k.startswith('DAT2/MG') or not k.endswith('.BIZ'):continue
    try:bo=decode(o.record(k))[0];bn=decode(n.record(k))[0]
    except Exception:continue
    if len(bo)<0x31020:continue
    try:ko={(s,i):w for s,i,w in I.banks(bo)};kn={(s,i):w for s,i,w in I.banks(bn)}
    except Exception:continue
    for key,w in ko.items():
        s,i=key;grp='dialogue' if s in(0,1) else 'sel%d'%s
        rec_tot[k]+=1
        jp=any(c<0x2000 and bo[384+c*200:384+(c+1)*200] not in ENG for c in w)
        if not jp:stat[grp]['englishOriginal']+=1;continue
        if tuple(kn.get(key,()))!=tuple(w):stat[grp]['translated']+=1;continue
        stat[grp]['remaining']+=1;rec_jp[k]+=1
        sig=hashlib.md5(repr([('c',c) if c>=0x2000 else hashlib.md5(bo[384+c*200:384+(c+1)*200]).hexdigest() for c in w]).encode()).hexdigest()
        uniq[grp].add(sig)
for g in sorted(stat):print(g,dict(stat[g]),'unique remaining',len(uniq[g]))
pickle.dump((dict(rec_jp),dict(rec_tot)),open(S+r'\audit3.pkl','wb'))
print('records with remaining dialogue-ish JP:');
for k,v in sorted(rec_jp.items(),key=lambda x:-x[1])[:100]:print(k.split('/')[-1],v,'/',rec_tot[k],end=' | ')

"""Execute the unchanged enrollment default copier with a bounded MIPS subset.

Inputs are private raw MGENT records and the private translation packet. This is
not a console/emulator gameplay test. No disc or saved game is modified.
"""
import argparse,hashlib,json,struct
from pathlib import Path
BASE=0x8017a000
DEST=0x801f1a00

def execute(overlay,field):
    regs=[0]*32;regs[4]=field;regs[31]=0x80000000
    memory=bytearray([0xa5]*0x60);pc=BASE+0x6a98;pending=None
    def read(addr,n):
        if BASE<=addr and addr+n<=BASE+len(overlay):return int.from_bytes(overlay[addr-BASE:addr-BASE+n],'little')
        if DEST<=addr and addr+n<=DEST+len(memory):return int.from_bytes(memory[addr-DEST:addr-DEST+n],'little')
        raise AssertionError(f'unbounded read {addr:x}')
    for step in range(512):
        if pc==regs[31]:return memory,step
        w=read(pc,4);op=w>>26;rs=(w>>21)&31;rt=(w>>16)&31;rd=(w>>11)&31;imm=w&65535;sgn=imm if imm<32768 else imm-65536;branch=None
        if op==0:
            fn=w&63
            if fn==0:regs[rd]=(regs[rt]<<((w>>6)&31))&0xffffffff
            elif fn==33:regs[rd]=(regs[rs]+regs[rt])&0xffffffff
            elif fn==8:branch=regs[rs]
            else:raise AssertionError(f'unsupported special {w:x}')
        elif op==15:regs[rt]=imm<<16
        elif op==9:regs[rt]=(regs[rs]+sgn)&0xffffffff
        elif op==10:regs[rt]=int((regs[rs] if regs[rs]<0x80000000 else regs[rs]-0x100000000)<sgn)
        elif op==13:regs[rt]=regs[rs]|imm
        elif op in (35,37):regs[rt]=read((regs[rs]+sgn)&0xffffffff,4 if op==35 else 2)
        elif op==41:
            addr=(regs[rs]+sgn)&0xffffffff;assert DEST<=addr and addr+2<=DEST+len(memory),'unbounded write';memory[addr-DEST:addr-DEST+2]=(regs[rt]&65535).to_bytes(2,'little')
        elif op in (4,5):
            taken=(regs[rs]==regs[rt]) if op==4 else (regs[rs]!=regs[rt]);branch=pc+4+sgn*4 if taken else pc+8
        elif op==2:branch=((pc+4)&0xf0000000)|((w&0x3ffffff)<<2)
        else:raise AssertionError(f'unsupported instruction {w:x}')
        regs[0]=0;pc=pending if pending is not None else pc+4;pending=branch
    raise AssertionError('copier did not terminate')

def audit(original,candidate,packet):
    src=original.read_bytes();new=candidate.read_bytes();data=json.loads(packet.read_text())
    assert hashlib.sha256(src).hexdigest()=='eaf243e2d5a78919055b453611ea8b785766a6dc945966a1d5c0ce166714f70a'
    assert len(src)==len(new)==36796 and src[:4]==new[:4] and src[0x34:]==new[0x34:]
    assert src[0x6a98:0x6b20]==new[0x6a98:0x6b20]
    keys=[v for v in struct.unpack('<70H',src[0xc7c:0xd08])if v!=0x61e];assert len(keys)==62
    results=[]
    for field,e in enumerate(data['default_names']):
        assert e['capacity']==[6,6,4][field] and len(e['name'])<=e['capacity']
        memory,steps=execute(new,field);words=[keys[10+ord(c)-ord('A')] for c in e['name']]+[0x3001];expected=struct.pack('<'+'H'*len(words),*words);at=[0x12,0x22,0x32][field]
        assert memory[at:at+len(expected)]==expected
        assert all(v==0xa5 for i,v in enumerate(memory)if not at<=i<at+len(expected)), 'write escaped selected name field'
        results.append({'field':field,'name':e['name'],'instructions':steps,'capacity':e['capacity'],'termination_and_neighbor_canaries':'passed'})
    return results

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('original',type=Path);p.add_argument('candidate',type=Path);p.add_argument('packet',type=Path);a=p.parse_args();print(json.dumps(audit(a.original,a.candidate,a.packet),indent=2))

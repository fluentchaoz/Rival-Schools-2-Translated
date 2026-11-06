"""Audit the native CD locator signatures against actual or planned ISO records."""
import struct

def catalog_key(lba,size):
 absolute=lba+150;minute=absolute//4500;second=absolute%4500//75;frame=absolute%75
 if not 0<=minute<100:raise ValueError('native catalog position range')
 def bcd(n):return n//10*16+n%10
 return bytes([bcd(minute),bcd(second),bcd(frame),0])+struct.pack('<I',size)

def audit_catalog(disc,replacements=None):
 replacements=replacements or {};exe=replacements.get('SLPS_021.20')
 if exe is None:exe=disc.record('SLPS_021.20')
 bound=0;mismatches=[]
 for path,(lba,size)in disc.records.items():
  key=catalog_key(lba,size);p=0
  while True:
   p=exe.find(key,p)
   if p<0:break
   if p%4==0 and p+12<=len(exe):
    stored=replacements.get(path)
    if stored is None:stored=disc.record(path)
    if len(stored)!=size:raise ValueError('catalog size differs: '+path)
    expected=exe[p+8:p+12];actual=stored[:4];bound+=1
    if expected!=actual:mismatches.append(dict(path=path,catalog_offset=p,signature_offset=p+8,expected=expected.hex(),actual=actual.hex()))
   p+=1
 return dict(bound_entries=bound,mismatches=mismatches)

def require_catalog(disc,replacements=None):
 result=audit_catalog(disc,replacements)
 if result['mismatches']:raise ValueError('Native catalog signature mismatch: '+str(result['mismatches']))
 return result

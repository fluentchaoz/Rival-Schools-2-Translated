"""Print the work queue: python tools/queue_status.py   (status = folder; see queue/README.md)."""
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')  # titles contain Japanese; Windows consoles default to cp1252

Q = Path(__file__).resolve().parents[1] / 'queue'
for folder in ('open', 'in-progress', 'done'):
    files = sorted(p for p in (Q / folder).glob('*.md'))
    print(f'== {folder} ({len(files)})')
    for p in files:
        text = p.read_text(encoding='utf-8')
        title = (re.search(r'^# (.+)$', text, re.M) or [None, p.stem])[1]
        needs = (re.search(r'^\*\*Needs:\*\* (.+)$', text, re.M) or [None, '?'])[1]
        claim = (re.search(r'^\*\*Claimed by:\*\* (.+)$', text, re.M) or [None, '-'])[1]
        extra = f'  [claimed: {claim}]' if folder == 'in-progress' else ''
        print(f'  {title}  (needs: {needs}){extra}')

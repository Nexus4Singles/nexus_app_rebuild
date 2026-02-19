#!/usr/bin/env python3
import json, os, glob, re

base = 'assets/config/journeys'
folders = ['singles journeys', 'married journeys', 'divorced journeys', 'widowed journeys']
huge = []
for folder in folders:
    path = os.path.join(base, folder)
    for fp in sorted(glob.glob(os.path.join(path, '*.json'))):
        fname = os.path.basename(fp)
        with open(fp) as f:
            data = json.load(f)
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                cid = card.get('cardId') or card.get('id') or '?'
                text = card.get('text', '')
                for m in re.finditer(r'\{red\|([^}]*)\}', text, re.DOTALL):
                    inner = m.group(1)
                    lines = inner.count('\n') + 1
                    if lines > 15:
                        huge.append((fname, cid, lines, len(inner)))
print(f'Found {len(huge)} huge red spans (>15 lines):')
for fn, ci, ln, ch in sorted(huge, key=lambda x: -x[2]):
    print(f'  {fn} {ci}: {ln} lines, {ch} chars')

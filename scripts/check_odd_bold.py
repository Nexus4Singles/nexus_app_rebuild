#!/usr/bin/env python3
"""Scan all journey files for odd ** count (unpaired bold markers)."""
import json, glob, os, re

d = 'assets/config/journeys'
errors = 0
total = 0
odd_bold = []

for f in sorted(glob.glob(os.path.join(d, '**/*.json'), recursive=True)):
    bn = os.path.basename(f)
    if not any(bn.startswith(p) for p in ['singles_', 'married_', 'divorced_', 'widowed_']):
        continue
    total += 1
    try:
        data = json.load(open(f))
    except Exception as e:
        errors += 1
        continue
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for ai, act in enumerate(data[key]):
            for ci, c in enumerate(act.get('cards', [])):
                for fld in ['text', 'reflection']:
                    txt = c.get(fld, '')
                    if not txt:
                        continue
                    count = len(re.findall(r'\*\*', txt))
                    if count % 2 != 0:
                        title = c.get('title', c.get('id', '?'))
                        odd_bold.append(f'{bn} act{ai} c{ci} ({title}): {count} markers')

print(f'Validated {total} files, {errors} JSON errors')
print(f'Odd bold count: {len(odd_bold)} cards')
for x in odd_bold:
    print(f'  {x}')

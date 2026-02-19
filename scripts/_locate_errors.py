#!/usr/bin/env python3
"""Find exact locations for all ERRORS from deep review."""
import json, re, glob
from pathlib import Path

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

print("=" * 80)
print("LOCATING ALL ERRORS AND KEY WARNINGS")
print("=" * 80)

for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    for fp in sorted(folder_path.glob("*.json")):
        fname = fp.name
        with open(fp, 'r') as f:
            raw = f.read()
            f.seek(0)
            data = json.load(f)
        
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                cid = card.get('cardId') or card.get('id', '?')
                
                for field in ['text', 'reflection']:
                    text = card.get(field)
                    if not text:
                        continue
                    
                    # DOUBLE_OPEN_PAREN
                    for m in re.finditer(r'\(\({red\|', text):
                        ctx = text[max(0,m.start()-30):m.end()+30]
                        print(f"\n❌ DOUBLE_OPEN_PAREN: {fname} {cid}/{field}")
                        print(f"   → ...{ctx}...")
                    
                    # EMPTY_PARENS
                    for m in re.finditer(r'\(\s*\)', text):
                        ctx = text[max(0,m.start()-40):m.end()+20]
                        print(f"\n❌ EMPTY_PARENS: {fname} {cid}/{field}")
                        print(f"   → ...{ctx}...")
                    
                    # ORPHAN_OPEN_BRACE
                    cleaned = re.sub(r'\{red\|[^}]*\}', '', text)
                    if '{' in cleaned:
                        idx = cleaned.index('{')
                        ctx = cleaned[max(0,idx-30):idx+40]
                        print(f"\n❌ ORPHAN_OPEN_BRACE: {fname} {cid}/{field}")
                        print(f"   → ...{ctx}...")
                    
                    # DUPLICATE_PARA
                    paras = [p.strip() for p in text.split('\n') if p.strip()]
                    from collections import Counter
                    for p, c in Counter(paras).items():
                        if c > 1 and len(p) > 20:
                            print(f"\n❌ DUPLICATE_PARA: {fname} {cid}/{field}")
                            print(f"   Repeated {c}x: '{p[:80]}...'")
                    
                    # BROKEN_NAME_SPLIT
                    lines = text.split('\n')
                    for i, line in enumerate(lines):
                        if re.search(r'(?:Dr|Mr|Mrs|Ms|Rev|St|Mt)\.\s*$', line.strip()):
                            next_c = ""
                            for j in range(i+1, len(lines)):
                                if lines[j].strip():
                                    next_c = lines[j].strip()[:50]
                                    break
                            if next_c and next_c[0].isupper():
                                print(f"\n⚠️  BROKEN_NAME_SPLIT: {fname} {cid}/{field}")
                                print(f"   → '{line.strip()}' | '{next_c}'")
                    
                    # DUPLICATE_RED
                    red_spans = re.findall(r'\{red\|([^}]*)\}', text)
                    for span, count in Counter(red_spans).items():
                        if count > 1 and len(span) > 5:
                            print(f"\n⚠️  DUPLICATE_RED: {fname} {cid}/{field}")
                            print(f"   '{span[:60]}' repeated {count}x")
                
                # TITLE_ENDS_PERIOD
                title = card.get('title', '')
                if title and title.endswith('.'):
                    print(f"\n⚠️  TITLE_ENDS_PERIOD: {fname} {cid}/title")
                    print(f"   → '{title}'")

print("\n\nDone.")

#!/usr/bin/env python3
"""
Find text fields where list-like content exists but isn't properly bulleted/numbered.
Patterns:
1. A line ending with ":" followed by 3+ short lines (< 80 chars) without bullets
2. Consecutive lines all starting with a bold keyword pattern
3. Multiple "You **verb**" lines that form a recap list
"""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

findings = []

for folder in ["singles journeys","married journeys","divorced journeys","widowed journeys"]:
    fp = BASE / folder
    if not fp.exists(): continue
    for f in sorted(fp.glob("*.json")):
        if f.name not in ACTIVE: continue
        data = json.load(open(f))
        cards = []
        for act in data.get("activities",[]): cards.extend(act.get("cards",[]))
        for mis in data.get("missions",[]): cards.extend(mis.get("cards",[]))
        
        for card in cards:
            text = card.get("text","")
            if not text: continue
            cid = card.get("cardId", card.get("id",""))
            lines = text.split("\n")
            
            # Pattern 1: Header ending with ":" followed by short lines
            i = 0
            while i < len(lines):
                s = lines[i].strip()
                
                # Is this a header line ending with colon?
                if s.endswith(':') and len(s) > 5 and len(s) < 100:
                    # Count following short non-empty lines without bullets
                    j = i + 1
                    items = []
                    while j < len(lines):
                        ns = lines[j].strip()
                        if not ns:  # blank
                            j += 1
                            continue
                        if ns.startswith(('•','- ','* ')) or re.match(r'^\d+\.', ns):
                            break  # already bulleted
                        if len(ns) < 80 and not ns.endswith(':'):
                            items.append((j, ns))
                            j += 1
                        else:
                            break
                    
                    if len(items) >= 3:
                        findings.append((f.name, cid, f"L{i+1}", "HEADER_THEN_UNBULLETED",
                            f"Header: '{s[:50]}' → {len(items)} items, first: '{items[0][1][:50]}'"))
                
                i += 1
            
            # Pattern 2: Consecutive lines with **Bold** word at start (recap lists)
            i = 0
            while i < len(lines):
                s = lines[i].strip()
                if re.match(r'\*\*\w', s) and not s.startswith('•') and not s.startswith('- '):
                    consecutive = [(i, s)]
                    j = i + 1
                    while j < len(lines):
                        ns = lines[j].strip()
                        if not ns:
                            j += 1
                            continue
                        if re.match(r'\*\*\w', ns) and not ns.startswith('•') and not ns.startswith('- '):
                            consecutive.append((j, ns))
                            j += 1
                        else:
                            break
                    
                    if len(consecutive) >= 4:
                        # Check: are these list items or paragraphs?
                        avg_len = sum(len(c[1]) for c in consecutive) / len(consecutive)
                        if avg_len < 120:  # Short enough to be list items
                            findings.append((f.name, cid, f"L{i+1}", "BOLD_LIST_NO_BULLETS",
                                f"{len(consecutive)} bold items, first: '{consecutive[0][1][:50]}'"))
                    i = j
                else:
                    i += 1

# Group by type
cats = {}
for fname, cid, loc, itype, desc in findings:
    cats[itype] = cats.get(itype, 0) + 1

print("POTENTIAL UN-ITEMIZED CONTENT:")
for k, v in sorted(cats.items(), key=lambda x:-x[1]):
    print(f"  {k}: {v}")

print(f"\nDETAILS ({len(findings)}):")
for fname, cid, loc, itype, desc in findings:
    print(f"  {fname} | {cid} {loc} [{itype}]: {desc}")

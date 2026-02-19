#!/usr/bin/env python3
"""
Deep analysis: find ALL formatting issues including:
1. Bold-in-word (missing space after **)
2. Labels that should be bold but aren't (Label: pattern at start of line w/o bold)
3. Lists of items that should have bullet prefixes
4. Closing ** in wrong position
"""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

all_issues = []

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
            for fld in ["text","prompt","reflection"]:
                text = card.get(fld,"")
                if not text: continue
                cid = card.get("cardId", card.get("id",""))
                lines = text.split("\n")
                
                for i, line in enumerate(lines):
                    s = line.strip()
                    if not s: continue
                    
                    # Issue 1: Bold glued to next word (missing space)
                    # **Word**nextword or word**nextword
                    for m in re.finditer(r'\*\*([a-zA-Z])', s):
                        pos = m.start()
                        if pos >= 2 and s[pos-2:pos] != '**':
                            # This is a ** opening, check if it's glued
                            # Actually this is fine - **Word is normal bold opening
                            pass
                    
                    # Check for }**word or )**word or "**word
                    for m in re.finditer(r'\*\*([a-z])', s):
                        pos = m.start()
                        if pos >= 1 and s[pos-1] in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ':
                            # word** immediately followed by lowercase = bold close running into next word
                            ctx = s[max(0,pos-15):pos+15]
                            all_issues.append((f.name, cid, "BOLD_GLUED", f"L{i+1}", ctx))
                    
                    # Issue 2: Lines that look like list items but have no bullet/number prefix
                    # After a "header" line (ending with :), subsequent lines should be bulleted
                    # Look for consecutive short lines that describe items
                    
                    # Issue 3: **word**space immediately followed by normal text - check for missing space
                    for m in re.finditer(r'\*\*\w+\*\*\w', s):
                        ctx = s[max(0,m.start()-5):m.end()+10]
                        all_issues.append((f.name, cid, "BOLD_NOSPACE", f"L{i+1}", ctx))

# Now look for un-bulleted list sections
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
            for fld in ["text"]:
                text = card.get(fld,"")
                if not text: continue
                cid = card.get("cardId", card.get("id",""))
                lines = text.split("\n")
                
                # Find consecutive lines with **Label:** pattern (bold label lists)
                # These are already formatted as lists - check they have bullets
                i = 0
                while i < len(lines):
                    s = lines[i].strip()
                    # Is this a bold label line? Pattern: **Word(s):** rest
                    if re.match(r'\*\*[^*]+:\*\*\s', s):
                        # count consecutive
                        j = i + 1
                        count = 1
                        while j < len(lines):
                            ns = lines[j].strip()
                            if not ns:
                                j += 1
                                continue
                            if re.match(r'\*\*[^*]+:\*\*\s', ns):
                                count += 1
                                j += 1
                            else:
                                break
                        if count >= 3:
                            # These are list items - do they have bullet prefix?
                            has_bullet = any(lines[k].strip().startswith(('•','- ')) 
                                           for k in range(i, min(j, len(lines)))
                                           if lines[k].strip())
                            if not has_bullet:
                                all_issues.append((f.name, cid, "UNBULLETED_LIST", f"L{i+1}-{j}", 
                                    f"{count} items like: {s[:60]}"))
                        i = j
                    else:
                        i += 1

# Print
cats = {}
for fname, cid, itype, loc, ctx in all_issues:
    cats[itype] = cats.get(itype, 0) + 1

print("ISSUE SUMMARY:")
for k, v in sorted(cats.items(), key=lambda x:-x[1]):
    print(f"  {k}: {v}")

print(f"\nDETAILS ({len(all_issues)} total):")
for fname, cid, itype, loc, ctx in all_issues:
    print(f"  [{itype}] {fname} | {cid} {loc}: {ctx}")

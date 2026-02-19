#!/usr/bin/env python3
"""
Comprehensive analysis of formatting damage done by fix passes.
Identify:
1. Bold labels that lost their bold (**Label:** became Label:)
2. Broken bold markers (** in wrong position)
3. Content that should have bullets but doesn't
4. Lines that look like list items but have no prefix
"""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

issues = {
    "unbold_labels": 0,
    "broken_bold_pos": 0,
    "should_be_bulleted": 0,
    "orphan_bold_close": 0,
}

details = []

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
                    
                    # Pattern 1: Broken bold position - ** in middle or wrong spot
                    # e.g. "Internal processors** think" or "word** more"
                    for m in re.finditer(r'(\w)\*\*\s+(\w)', s):
                        before = s[max(0,m.start()-20):m.end()+20]
                        # Skip if it's actually a valid close: **word** text
                        pre = s[:m.start()+1]
                        if '**' in pre[:pre.rfind('**')] if '**' in pre else False:
                            continue
                        details.append((f.name, cid, "BROKEN_BOLD_POS", before))
                        issues["broken_bold_pos"] += 1
                    
                    # Pattern 2: word** at end of label with no opening **
                    # e.g. "Gridlocklooks like:" or "Dialoguelooks like:"
                    if re.search(r'\w\*\*\w', s):
                        m = re.search(r'\w\*\*\w', s)
                        ctx = s[max(0,m.start()-15):m.end()+15]
                        details.append((f.name, cid, "BOLD_IN_WORD", ctx))
                        issues["broken_bold_pos"] += 1

# Print summary
print(f"Issues found:")
for k, v in issues.items():
    print(f"  {k}: {v}")

print(f"\nAll BROKEN_BOLD_POS and BOLD_IN_WORD details:")
for fname, cid, itype, ctx in details:
    print(f"  {fname} | {cid} | {itype}: ...{ctx}...")

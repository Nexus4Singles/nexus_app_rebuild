#!/usr/bin/env python3
"""
Find text fields where content looks like it should be itemized but isn't.
Patterns that suggest a missing bullet/number conversion:
  - Comma-separated items after a colon header
  - Multiple sentences that are parallel/list-like
  - "Label: description" repeated patterns without bullets
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
            for fld in ["text","prompt","reflection"]:
                text = card.get(fld,"")
                if not text: continue
                cid = card.get("cardId", card.get("id",""))
                lines = text.split("\n")
                
                for i, line in enumerate(lines):
                    s = line.strip()
                    
                    # Pattern 1: **Label:** content on same line as header
                    # followed by more **Label:** lines  (this is a list that should have bullets)
                    # We check consecutive **Label:** patterns
                    if re.match(r'\*\*[^*]+:\*\*\s+\S', s):
                        # Look at next lines
                        j = i + 1
                        consecutive = 1
                        while j < len(lines):
                            ns = lines[j].strip()
                            if not ns:
                                j += 1
                                continue
                            if re.match(r'\*\*[^*]+:\*\*\s+\S', ns):
                                consecutive += 1
                                j += 1
                            else:
                                break
                        if consecutive >= 3:
                            findings.append((f.name, cid, fld, f"Consecutive **Label:** lines ({consecutive}) could use bullets", s[:70]))
                            break  # once per card field
                    
                    # Pattern 2: Plain numbered list without proper formatting
                    # "1. item  2. item  3. item" all on one line (already fixed, skip)
                    
                    # Pattern 3: Long "plain" lines starting with a bold label but no bullet
                    # These are items that HAVE bold labels but no bullet prefix
                    if re.match(r'\*\*[^*]+:\*\*', s) and not s.startswith('•') and not s.startswith('-'):
                        # Check if neighbors are the same pattern
                        pass  # Already caught in Pattern 1

# Print findings
print(f"Found {len(findings)} potential un-itemized sections:\n")
for fname, cid, fld, desc, ctx in findings[:30]:
    print(f"  {fname} | {cid}/{fld}: {desc}")
    print(f"    → {ctx}")
    print()

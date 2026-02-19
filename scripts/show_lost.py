#!/usr/bin/env python3
"""Show lost bullet/numbered lines by comparing git HEAD vs current."""
import json, subprocess, re

files = [
    ("assets/config/journeys/singles journeys/singles_journey_06_emotional_intelligence.json", "c3", "text"),
    ("assets/config/journeys/singles journeys/singles_journey_18_purity.json", "c1", "text"),
    ("assets/config/journeys/married journeys/married_journey_11_cultural_differences.json", "c6", "text"),
]

for fpath, cid, fld in files:
    result = subprocess.run(["git", "show", f"HEAD:{fpath}"], capture_output=True, text=True)
    git_data = json.loads(result.stdout)
    cur_data = json.load(open(fpath))
    
    for dataset, label in [(git_data, "GIT"), (cur_data, "CUR")]:
        cards = []
        for act in dataset.get("activities",[]): cards.extend(act.get("cards",[]))
        for mis in dataset.get("missions",[]): cards.extend(mis.get("cards",[]))
        for card in cards:
            if card.get("cardId", card.get("id","")) == cid:
                text = card.get(fld,"")
                for i, line in enumerate(text.split("\n")):
                    s = line.strip()
                    if s.startswith("• ") or s.startswith("- ") or re.match(r"^\d+\.\s", s):
                        print(f"  [{label}] {fpath.split('/')[-1]} {cid} L{i}: {s[:80]}")
    print()

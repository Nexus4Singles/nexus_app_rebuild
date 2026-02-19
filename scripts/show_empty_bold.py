#!/usr/bin/env python3
"""Show context around ** ** patterns to see if they're false positives."""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

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
                for m in re.finditer(r'\*\*\s*\*\*', text):
                    ctx = text[max(0,m.start()-40):m.end()+40].replace("\n","\\n")
                    cid = card.get("cardId", card.get("id",""))
                    print(f"{f.name} | {cid} | ...{ctx}...")

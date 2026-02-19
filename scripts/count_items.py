#!/usr/bin/env python3
"""Check current state of bullets and numbered items across all journey files."""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

bullet_count = 0
numbered_count = 0
total_texts = 0
dash_count = 0

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
                total_texts += 1
                for line in text.split("\n"):
                    s = line.strip()
                    if s.startswith("• "): bullet_count += 1
                    elif s.startswith("- "): dash_count += 1
                    elif re.match(r"^\d+\.\s", s): numbered_count += 1

print(f"Total text fields: {total_texts}")
print(f"Bullet points (•): {bullet_count}")
print(f"Dash items (-): {dash_count}")
print(f"Numbered items: {numbered_count}")

#!/usr/bin/env python3
"""Show actual BROKEN_RED_PAREN patterns from files to understand them."""
import json, re
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"
MAP_FILE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journey_id_filename_map.json"

FOLDERS = {
    "singles": BASE / "singles journeys",
    "married": BASE / "married journeys",
    "divorced": BASE / "divorced journeys",
    "widowed": BASE / "widowed journeys",
}

with open(MAP_FILE) as f:
    FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())

def get_all_active_files():
    files = []
    for folder in FOLDERS.values():
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES:
                files.append((fp, fp.name))
    return files

count = 0
for filepath, filename in get_all_active_files():
    with open(filepath) as f:
        data = json.load(f)
    
    cards = []
    for act in data.get("activities", []):
        for card in act.get("cards", []): cards.append((card, filename))
    for mission in data.get("missions", []):
        for card in mission.get("cards", []): cards.append((card, filename))
    
    for card, fname in cards:
        for key in ["text", "prompt", "reflection"]:
            if key not in card or not card[key]: continue
            text = card[key]
            for m in re.finditer(r'.{0,60}\}\).{0,60}', text):
                count += 1
                if count <= 40:
                    card_id = card.get("cardId") or card.get("id") or "?"
                    print(f"\n--- {fname} | {card_id} | {key} ---")
                    print(f"  {m.group(0)[:120]}")

print(f"\n\nTotal BROKEN_RED_PAREN occurrences: {count}")

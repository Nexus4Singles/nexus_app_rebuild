#!/usr/bin/env python3
"""Show remaining REAL issues (orphan quotes, unpaired bold, inline bullets)."""
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
with open(MAP_FILE) as f: FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())

def get_all_active_files():
    files = []
    for folder in FOLDERS.values():
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")): 
            if fp.name in ACTIVE_FILES: files.append((fp, fp.name))
    return files

orphan_count = 0
bold_count = 0
bullet_count = 0

for filepath, filename in get_all_active_files():
    with open(filepath) as f: data = json.load(f)
    cards = []
    for act in data.get("activities", []):
        for card in act.get("cards", []): cards.append(card)
    for mission in data.get("missions", []):
        for card in mission.get("cards", []): cards.append(card)
    
    for card in cards:
        card_id = card.get("cardId") or card.get("id") or "?"
        for key in ["text", "prompt", "reflection"]:
            if key not in card or not card[key]: continue
            text = card[key]
            lines = text.split('\n')
            
            for i, line in enumerate(lines):
                stripped = line.strip()
                
                # Orphan quotes
                if stripped in ('"', '\u201c', '\u201d', "'"):
                    orphan_count += 1
                    context_before = lines[i-1].strip()[-40:] if i > 0 else ""
                    context_after = lines[i+1].strip()[:40] if i+1 < len(lines) else ""
                    if orphan_count <= 20:
                        print(f"ORPHAN_QUOTE | {filename} | {card_id}")
                        print(f"  L{i}: ...{context_before}")
                        print(f"  L{i+1}: {stripped}")
                        print(f"  L{i+2}: {context_after}...\n")
                
                # Unpaired bold
                bold_markers = line.count('**')
                if bold_markers % 2 != 0 and bold_markers > 0:
                    bold_count += 1
                    if bold_count <= 20:
                        print(f"UNPAIRED_BOLD | {filename} | {card_id}")
                        print(f"  L{i+1} ({bold_markers} markers): {stripped[:100]}\n")
                
                # Inline bullets
                bullet_hits = len(re.findall(r'[•\-\*]\s', line))
                if bullet_hits >= 2 and len(line) > 40:
                    # Filter: don't count if line has ** bold markers (which use *)
                    clean = line.replace('**', '')
                    if len(re.findall(r'[•\-]\s', clean)) >= 2:
                        bullet_count += 1
                        if bullet_count <= 10:
                            print(f"INLINE_BULLETS | {filename} | {card_id}")
                            print(f"  L{i+1}: {stripped[:120]}\n")

print(f"\nSUMMARY:")
print(f"  Orphan quotes: {orphan_count}")
print(f"  Unpaired bold: {bold_count}")
print(f"  Inline bullets: {bullet_count}")

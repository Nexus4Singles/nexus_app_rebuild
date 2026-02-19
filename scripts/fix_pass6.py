#!/usr/bin/env python3
"""
Pass 6: Fix final 9 unpaired bold patterns.
A. Trailing ** or **' or **" at end of line → remove
B. Bullet lines like • **Label: text → • **Label:** text
C. mid-text stray **
"""
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


def fix_text(text):
    if not text or not text.strip():
        return text
    
    lines = text.split('\n')
    for i, line in enumerate(lines):
        stripped = line.strip()
        count = stripped.count('**')
        if count == 0 or count % 2 == 0:
            continue
        
        # Pattern A: word!**' or word.**' or word.**" → remove the **
        # e.g. "servant!**'" → "servant!'"
        # e.g. "me.**'" → "me.'"
        # e.g. "thing!**\"" → "thing!\""
        stripped = re.sub(r'\*\*([\'"])', r'\1', stripped)
        
        # Pattern B: trailing ** at end of line (odd marker)
        # Re-count after previous fix
        count = stripped.count('**')
        if count % 2 != 0 and stripped.endswith('**'):
            stripped = stripped[:-2].rstrip()
        
        # Pattern C: bullet lines with **Label: (no close)
        # • **Shared values: 'We believe.'  →  • **Shared values:** 'We believe.'
        count = stripped.count('**')
        if count == 1 and '**' in stripped and ':' in stripped:
            star_pos = stripped.find('**')
            colon_pos = stripped.find(':', star_pos)
            if colon_pos > star_pos:
                label = stripped[star_pos+2:colon_pos]
                if label and len(label) < 80 and '**' not in label:
                    before = stripped[:star_pos]
                    rest = stripped[colon_pos+1:].lstrip()
                    stripped = f'{before}**{label}:** {rest}'
        
        lines[i] = stripped
    
    return '\n'.join(lines)


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 6)...\n")
    
    modified_count = 0
    for filepath, filename in files:
        with open(filepath) as f: data = json.load(f)
        modified = False
        
        def process_cards(cards):
            nonlocal modified
            for card in cards:
                for field in ["text", "prompt", "reflection"]:
                    if field in card and card[field] and isinstance(card[field], str):
                        original = card[field]
                        fixed = fix_text(original)
                        if fixed != original:
                            card[field] = fixed
                            modified = True
        
        for act in data.get("activities", []):
            process_cards(act.get("cards", []))
        for mission in data.get("missions", []):
            process_cards(mission.get("cards", []))
        
        if modified:
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write('\n')
            modified_count += 1
            print(f"  ✓ {filename}")
    
    print(f"\nModified {modified_count}/{len(files)} files.")
    
    errors = 0
    for filepath, filename in files:
        try:
            with open(filepath) as f: json.load(f)
        except json.JSONDecodeError as e:
            print(f"  ✗ JSON ERROR: {filename}: {e}")
            errors += 1
    print(f"JSON validation: {errors} errors")

if __name__ == "__main__":
    main()

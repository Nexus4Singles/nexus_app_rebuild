#!/usr/bin/env python3
"""
Pass 5: Fix unpaired opening bold caused by pass 4 removing closing **.
Pattern: **Label text: rest of line  →  **Label text:** rest of line
Only when ** opens at start and has no matching close.
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
        
        # Pattern: line starts with ** and has exactly 1 ** marker (no close)
        # AND contains a colon  →  close bold at the colon
        if count == 1 and stripped.startswith('**') and ':' in stripped:
            # Find the first colon
            colon_pos = stripped.index(':')
            label = stripped[2:colon_pos]  # text between ** and :
            rest = stripped[colon_pos+1:]  # text after :
            # Only fix if the label portion is reasonable (< 80 chars, no ** in it)
            if len(label) < 80 and '**' not in label:
                lines[i] = f'**{label}:** {rest.lstrip()}'
        
        # Pattern: line has exactly 1 ** marker NOT at start and not at end
        # These are stray ** markers mid-line
        elif count == 1 and not stripped.startswith('**') and not stripped.endswith('**'):
            # Find position
            pos = stripped.find('**')
            before = stripped[:pos]
            after = stripped[pos+2:]
            # If it's between words (not part of a bold pair), remove it
            # But be careful - this might be a legitimate start of bold
            # Only remove if there's no closing ** anywhere in subsequent lines
            # For safety, skip these for now
            pass
    
    return '\n'.join(lines)


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 5)...\n")
    
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

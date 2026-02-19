#!/usr/bin/env python3
"""
Pass 7: Final cleanup — split inline numbered lists, fix trailing whitespace.
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
    
    # 1. Split inline numbered lists onto separate lines
    # Pattern: "1. text 2. text 3. text" → "1. text\n2. text\n3. text"
    lines = text.split('\n')
    new_lines = []
    for line in lines:
        stripped = line.strip()
        # Count numbered items on this line
        # Pattern: digit(s). followed by space and text
        items = re.findall(r'(?:^|\s)(\d+)\.\s', stripped)
        
        if len(items) >= 3 and len(stripped) > 60:
            # Split at each numbered item boundary
            # Find positions of each "N. " pattern
            parts = re.split(r'(?:^|\s)(?=\d+\.\s)', stripped)
            parts = [p.strip() for p in parts if p.strip()]
            
            if len(parts) >= 3:
                for p in parts:
                    new_lines.append(p)
                continue
        
        new_lines.append(line)
    
    text = '\n'.join(new_lines)
    
    # 2. Fix trailing whitespace
    lines = text.split('\n')
    lines = [line.rstrip() for line in lines]
    text = '\n'.join(lines)
    
    # 3. Clean up excess newlines (3+ → 2)
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    return text.strip()


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 7)...\n")
    
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

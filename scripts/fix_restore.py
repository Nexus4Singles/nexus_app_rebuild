#!/usr/bin/env python3
"""
Restoration pass: Fix bold-glued issues and enhance itemized content with bullets.

Fixes:
1. Bold glued to next word: **Word**nextword → **Word** nextword
2. word**nextword → word** nextword  
3. Add • bullets to consecutive **Label:** lines that don't already have them
4. Ensure proper spacing in list-like content
"""
import json, re
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

FOLDERS = [
    BASE / "singles journeys",
    BASE / "married journeys",
    BASE / "divorced journeys",
    BASE / "widowed journeys",
]


def get_all_active_files():
    files = []
    for folder in FOLDERS:
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE: files.append((fp, fp.name))
    return files


def fix_bold_glued(text):
    """Fix cases where bold markers are glued to adjacent words."""
    # **Word**nextword → **Word** nextword
    # But NOT **W**ord (single letter bold for acronyms - that's intentional)
    text = re.sub(r'\*\*([A-Za-z]{2,})\*\*([a-z])', r'**\1** \2', text)
    
    # word**nextword → word** nextword (closing bold glued to next word)
    text = re.sub(r'([a-z])\*\*([a-z])', r'\1** \2', text)
    
    # word**looks → word** looks, word**asks → word** asks etc  
    text = re.sub(r'(\w)\*\*([a-z])', r'\1** \2', text)
    
    return text


def add_bullets_to_label_lists(text):
    """Add • prefix to consecutive **Label:** lines that form a list."""
    lines = text.split('\n')
    new_lines = []
    i = 0
    
    while i < len(lines):
        s = lines[i].strip()
        
        # Check if this is a **Label:** line (bold label with colon)
        if re.match(r'\*\*[^*]+:\*\*\s', s) and not s.startswith('•') and not s.startswith('- '):
            # Look ahead to count consecutive similar lines
            j = i + 1
            count = 1
            indices = [i]
            while j < len(lines):
                ns = lines[j].strip()
                if not ns:  # empty line
                    j += 1
                    continue
                if re.match(r'\*\*[^*]+:\*\*\s', ns) and not ns.startswith('•') and not ns.startswith('- '):
                    count += 1
                    indices.append(j)
                    j += 1
                else:
                    break
            
            if count >= 3:
                # This is a list - add bullets to each item
                for idx in indices:
                    if not lines[idx].strip().startswith('•'):
                        lines[idx] = '• ' + lines[idx].strip()
            
            new_lines.extend(lines[i:j])
            i = j
        else:
            new_lines.append(lines[i])
            i += 1
    
    return '\n'.join(new_lines)


def ensure_bullet_line_breaks(text):
    """Ensure bullet items are each on their own line with proper spacing."""
    # Split inline bullets: "• item1 • item2" → "• item1\n• item2"
    text = re.sub(r'(• [^\n•]+)\s+(• )', r'\1\n\2', text)
    
    return text


def process_text(text):
    if not text or not text.strip():
        return text
    t = fix_bold_glued(text)
    t = add_bullets_to_label_lists(t)
    t = ensure_bullet_line_breaks(t)
    return t


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (restoration pass)...\n")
    
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
                        fixed = process_text(original)
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
    
    # Validate
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

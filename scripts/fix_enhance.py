#!/usr/bin/env python3
"""
Fix 3 specific cards that lost bullets/numbers, then enhance all files
by adding bullets to clearly list-like content.
"""
import json, re, subprocess
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


# ============================================================
# PART 1: Restore specific lost items
# ============================================================

def restore_purity_c1(filepath):
    """Restore 4 lost bullet items in singles_journey_18_purity.json c1."""
    with open(filepath) as f: data = json.load(f)
    
    for act in data.get("activities", []):
        for card in act.get("cards", []):
            if card.get("cardId") != "c1": continue
            text = card.get("text", "")
            
            # The lost section was the "What purity brings" bullets:
            # • **Self-control**, The ability to direct desire appropriately
            # • **Clean conscience**, No comparisons or regrets
            # • **Undivided heart**, No soul ties from previous partners
            # • **Healthy expectations**, Not warped by porn or multiple partners
            # These should be in the text somewhere. Check if they're missing.
            if "Self-control" not in text or "Clean conscience" not in text:
                # They were removed. Add them back before "Purity isn't"
                bullets = (
                    "\n\n• **Self-control:** The ability to direct desire appropriately"
                    "\n• **Clean conscience:** No comparisons or regrets"
                    "\n• **Undivided heart:** No soul ties from previous partners"
                    "\n• **Healthy expectations:** Not warped by porn or multiple partners"
                )
                # Find where to insert - before "Purity isn't" or at end
                if "Purity isn" in text:
                    text = text.replace("Purity isn", bullets + "\n\nPurity isn", 1)
                else:
                    text += bullets
                card["text"] = text
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("  ✓ Restored purity c1 bullets")


def restore_cultural_c6(filepath):
    """Restore lost numbered item 1 in married_journey_11 c6."""
    with open(filepath) as f: data = json.load(f)
    
    for act in data.get("activities", []):
        for card in act.get("cards", []):
            if card.get("cardId") != "c6": continue
            text = card.get("text", "")
            
            # Item 1 is missing: "1. [How we will approach cultural differences with curiosity]"
            if "2. [How we will handle" in text and "1. [How we will approach" not in text:
                text = text.replace(
                    "2. [How we will handle",
                    "1. [How we will approach cultural differences with curiosity]\n\n2. [How we will handle"
                )
                card["text"] = text
    
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print("  ✓ Restored cultural c6 item 1")


# ============================================================
# PART 2: Enhance list-like content with bullets
# ============================================================

def enhance_lists(text):
    """Add bullets to clearly list-like content that lacks them.
    
    Strategy:
    1. After a line ending with ":", if next 3+ lines are short items → add •
    2. BUT exclude: quoted dialogue, prayer text, narrative paragraphs
    3. Only bullet lines that are clearly list items (< 80 chars, no full sentences ending in period+capital)
    """
    if not text or not text.strip():
        return text
    
    lines = text.split('\n')
    new_lines = list(lines)  # copy
    i = 0
    
    while i < len(lines):
        s = lines[i].strip()
        
        # Find header lines ending with ":"
        if s.endswith(':') and len(s) > 5 and len(s) < 120:
            # Look at following lines
            j = i + 1
            item_indices = []
            
            while j < len(new_lines):
                ns = new_lines[j].strip()
                if not ns:  # blank line
                    j += 1
                    continue
                
                # Stop if: already bulleted, is a header, is too long, or is clearly narrative
                if ns.startswith(('•', '- ', '* ')) or re.match(r'^\d+\.', ns):
                    break  # Already formatted
                if ns.endswith(':') and len(ns) < 100:
                    break  # Another header
                if len(ns) > 100:
                    break  # Too long, probably a paragraph
                if ns.startswith(('{red|', 'This ', 'That ', 'But ', 'And ', 'However', 'The ')):
                    # Likely narrative continuation, not a list item
                    if len(ns) > 60:
                        break
                
                # Check if it looks like a list item:
                # - Short (< 80 chars)
                # - NOT a complete sentence that's clearly narrative
                # - Could be: bold label, quoted text, short phrase
                is_quoted = ns.startswith('"') or ns.startswith("'") or ns.startswith('"')
                is_bold_label = ns.startswith('**')
                is_short_phrase = len(ns) < 60
                
                if is_bold_label or is_short_phrase or is_quoted:
                    item_indices.append(j)
                    j += 1
                else:
                    break
            
            # Only add bullets if 3+ items found AND none already have bullets
            if len(item_indices) >= 3:
                already_bulleted = any(
                    new_lines[idx].strip().startswith(('•', '- ', '* '))
                    for idx in item_indices
                )
                if not already_bulleted:
                    for idx in item_indices:
                        stripped = new_lines[idx].strip()
                        if not stripped.startswith('•'):
                            new_lines[idx] = '• ' + stripped
            
            i = j
        else:
            i += 1
    
    return '\n'.join(new_lines)


def main():
    print("PART 1: Restoring lost items...\n")
    
    # Restore purity
    purity_path = BASE / "singles journeys" / "singles_journey_18_purity.json"
    if purity_path.exists():
        restore_purity_c1(purity_path)
    
    # Restore cultural
    cultural_path = BASE / "married journeys" / "married_journey_11_cultural_differences.json"
    if cultural_path.exists():
        restore_cultural_c6(cultural_path)
    
    print("\nPART 2: Enhancing list formatting across all files...\n")
    
    files = get_all_active_files()
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
                        fixed = enhance_lists(original)
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
    
    # Count final stats
    total_bullets = 0
    total_numbered = 0
    for filepath, filename in files:
        data = json.load(open(filepath))
        cards = []
        for act in data.get("activities",[]): cards.extend(act.get("cards",[]))
        for mis in data.get("missions",[]): cards.extend(mis.get("cards",[]))
        for card in cards:
            for fld in ["text","prompt","reflection"]:
                t = card.get(fld,"")
                if not t: continue
                for line in t.split("\n"):
                    s = line.strip()
                    if s.startswith("• ") or s.startswith("- "): total_bullets += 1
                    elif re.match(r"^\d+\.\s", s): total_numbered += 1
    
    print(f"\nFinal counts: {total_bullets} bullets, {total_numbered} numbered items")

if __name__ == "__main__":
    main()

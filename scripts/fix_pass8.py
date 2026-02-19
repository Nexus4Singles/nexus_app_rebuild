#!/usr/bin/env python3
"""
Pass 8: Fix 3 final issues manually identified.
1. singles_journey_02 c3: split ✓ items and bullet wall of text
2. singles_journey_13 c3: split items 5,6,7 numbered list
3. married_journey_15 c6: split "We commit to" statements
"""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"

def fix_file(filepath, card_id, transform_fn):
    with open(filepath) as f: data = json.load(f)
    modified = False
    for act in data.get("activities", []):
        for card in act.get("cards", []):
            if card.get("cardId") == card_id:
                original = card.get("text", "")
                fixed = transform_fn(original)
                if fixed != original:
                    card["text"] = fixed
                    modified = True
    if modified:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        print(f"  ✓ {filepath.name} ({card_id})")


def fix_singles_02(text):
    # Split ✓ items onto separate lines
    text = text.replace(' ✓ ', '\n✓ ')
    # Fix "us But notice" → paragraph break
    text = text.replace('us But notice', 'us\n\nBut notice')
    # Fix "problems (they come with you) Marriage adds" → paragraph break
    text = text.replace(') Marriage adds wonderful things.', ')\n\nMarriage adds wonderful things.')
    return text


def fix_singles_13(text):
    # Split items 5,6,7: 
    # **5. Name...continue." **6. Set timeline..." **7. Follow through.**
    # Add \n\n before each
    text = text.replace('continue." **6.', 'continue."\n\n**6.')
    text = text.replace('[timeframe]." **7.', '[timeframe]."\n\n**7.')
    return text


def fix_married_15(text):
    # Split "We commit to" statements onto separate lines
    text = text.replace('. We commit to', '.\n\nWe commit to')
    return text


def main():
    print("Fixing 3 final issues...\n")
    
    fix_file(
        BASE / "singles journeys" / "singles_journey_02_cultural_lies.json",
        "c3", fix_singles_02
    )
    fix_file(
        BASE / "singles journeys" / "singles_journey_13_red_flags.json",
        "c3", fix_singles_13
    )
    fix_file(
        BASE / "married journeys" / "married_journey_15_healthy_boundaries_extended_family.json",
        "c6", fix_married_15
    )
    
    # Verify JSON
    for folder in ["singles journeys", "married journeys"]:
        fp = BASE / folder
        for f in fp.glob("*.json"):
            try:
                json.load(open(f))
            except Exception as e:
                print(f"  ✗ JSON ERROR: {f.name}: {e}")
    
    print("\nDone.")

if __name__ == "__main__":
    main()

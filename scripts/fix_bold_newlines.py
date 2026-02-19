#!/usr/bin/env python3
"""
Critical fix: Repair **\n\n patterns where newlines ended up inside bold spans.
The previous scripts inserted \n\n between ** and the label text, creating:
  **\n\nLabel** instead of \n\n**Label**
This script moves the \n\n to BEFORE the ** opening.
"""

import json
import os
import re
import glob

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

changes = 0

def fix_text(text):
    if not text or not isinstance(text, str):
        return text
    original = text
    
    # Fix 1: **\n\nLabel → \n\n**Label (move newlines outside bold opening)
    # Pattern: ** followed by \n\n then text → \n\n** then text
    text = re.sub(r'\*\*\n\n([A-Za-z])', r'\n\n**\1', text)
    
    # Fix 2: **\n followed by text (single newline inside bold)
    text = re.sub(r'\*\*\n([A-Za-z])', r'\n**\1', text)
    
    # Fix 3: Remove bare ** that are on their own (just ** followed by \n\n)
    # These were created when the \n\n was inserted between opening ** and label,
    # and the label got its own ** later
    text = re.sub(r'\*\*\n\n\*\*', '\n\n**', text)
    
    # Fix 4: Clean up isolated ** markers (just ** on their own line or with only whitespace)
    text = re.sub(r'\n\*\*\n', '\n', text)
    
    # Fix 5: Remove ** that immediately precede another ** (doubled markers)
    text = re.sub(r'\*\*\s*\*\*', '**', text)
    
    # Fix 6: Fix "Label:**" where ** only appears at end (should be **Label:**)
    # Pattern: \n\nWord(s):** → \n\n**Word(s):**  
    text = re.sub(r'\n\n([A-Z][a-z][\w\s\']{2,40}):\*\*', r'\n\n**\1:**', text)
    # Also at start of text
    text = re.sub(r'^([A-Z][a-z][\w\s\']{2,40}):\*\*', r'**\1:**', text)
    
    # Cleanup triple+ newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()
    
    return text


def process_file(filepath):
    global changes
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for card in activity.get('cards', []):
                for field in ['text', 'reflection', 'prompt']:
                    if field in card and card[field] and isinstance(card[field], str):
                        card[field] = fix_text(card[field])
                if 'bullets' in card and card['bullets']:
                    card['bullets'] = [
                        fix_text(b) if isinstance(b, str) else b
                        for b in card['bullets']
                    ]
    
    updated = json.dumps(data, ensure_ascii=False)
    if original != updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        changes += 1
        return True
    return False


def main():
    global changes
    total = 0
    for f in sorted(glob.glob(os.path.join(JOURNEYS_DIR, '**/*.json'), recursive=True)):
        # Skip non-journey files
        basename = os.path.basename(f)
        if not any(basename.startswith(p) for p in ['singles_', 'married_', 'divorced_', 'widowed_']):
            continue
        total += 1
        if process_file(f):
            print(f"+ {basename}")
        else:
            print(f". {basename}")
    
    print(f"\n=== Done: {changes}/{total} modified ===")

if __name__ == '__main__':
    main()

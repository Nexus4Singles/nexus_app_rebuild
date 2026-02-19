#!/usr/bin/env python3
"""
Fix empty bold markers (** ** with only whitespace between)
and double periods (..)
"""

import json
import os
import re
import glob

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")


def fix_text(text):
    if not text or not isinstance(text, str):
        return text
    original = text

    # Remove empty bold: ** ** or **\n** or **\n\n** (just whitespace between markers)
    text = re.sub(r'\*\*\s*\*\*', '', text)
    
    # Fix double periods (but not triple/ellipsis)
    text = re.sub(r'\.\.(?!\.)', '.', text)
    
    # Clean up any resulting triple+ newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    # Clean up double spaces
    text = re.sub(r'  +', ' ', text)
    text = text.strip()
    
    return text


def process_file(filepath):
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
        return True
    return False


def main():
    total = 0
    modified = 0
    for f in sorted(glob.glob(os.path.join(JOURNEYS_DIR, '**/*.json'), recursive=True)):
        bn = os.path.basename(f)
        if not any(bn.startswith(p) for p in ['singles_', 'married_', 'divorced_', 'widowed_']):
            continue
        total += 1
        if process_file(f):
            modified += 1
    print(f"Done: {modified}/{total} modified")


if __name__ == '__main__':
    main()

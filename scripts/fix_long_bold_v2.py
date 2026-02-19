#!/usr/bin/env python3
"""
Remove excessive bold from long passages (>80 chars).
Keep bold only for:
- Headers/subheadings (end with : and are short)
- Keywords (short phrases)
- Quoted text (short)
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

    def check_bold_span(m):
        content = m.group(1)
        # Keep bold if it's short (< 80 chars)
        if len(content) <= 80:
            return m.group(0)
        # Keep if it's a label pattern (ends with :)
        if content.strip().endswith(':') and len(content) < 60:
            return m.group(0)
        # Remove bold from long passages
        return content

    text = re.sub(r'\*\*([^*]+)\*\*', check_bold_span, text)

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

#!/usr/bin/env python3
"""
FINAL Bold Label Fix: Restore closing ** on bold labels.

The problem: `**Label text.\n\n**Next label.\n\n` has NO closing ** on labels.
Fix: Find unclosed ** followed by short text + period/colon + \n\n, and add closing **.

Pattern: **Label text.\n\n → **Label text.**\n\n
Pattern: **Label text:\n   → **Label text:**\n
"""

import json
import os
import re
import glob

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

changes = 0
change_details = []


def fix_text(text, card_title=""):
    if not text or not isinstance(text, str):
        return text
    original = text

    # Fix 1: **LabelText.\n\n → **LabelText.**\n\n
    # Where LabelText is short (2-60 chars, no * or \n inside)
    text = re.sub(
        r'\*\*([^*\n]{2,60})\.\n\n',
        r'**\1.**\n\n',
        text
    )

    # Fix 2: **LabelText.\n• → **LabelText.**\n•
    text = re.sub(
        r'\*\*([^*\n]{2,60})\.\n(•)',
        r'**\1.**\n\2',
        text
    )

    # Fix 3: **LabelText.$ (at end of text) → **LabelText.**
    text = re.sub(
        r'\*\*([^*\n]{2,60})\.$',
        r'**\1.**',
        text
    )

    # Fix 4: **LabelText:\n\n → **LabelText:**\n\n
    # (closing colon-bold pattern for section headers)
    text = re.sub(
        r'\*\*([^*\n]{2,50}):\n',
        r'**\1:**\n',
        text
    )

    # Fix 5: Check for odd ** count and try to fix
    count = len(re.findall(r'\*\*', text))
    if count % 2 != 0:
        # Find last unpaired ** and try to close it
        # Common case: **Text that continues to end without close
        positions = [(m.start(), m.end()) for m in re.finditer(r'\*\*', text)]
        if len(positions) % 2 != 0:
            # Last ** is unpaired
            last_start = positions[-1][1]
            rest = text[last_start:]
            # Find reasonable close point (next period, colon, or end of line)
            m = re.search(r'[.:]\s', rest)
            if m:
                insert_at = last_start + m.start() + 1
                text = text[:insert_at] + '**' + text[insert_at:]
            else:
                # Close at end of current line
                m2 = re.search(r'\n', rest)
                if m2:
                    insert_at = last_start + m2.start()
                    text = text[:insert_at] + '**' + text[insert_at:]

    # Cleanup: no triple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)

    if text != original:
        change_details.append(f"  Fixed: {card_title}")

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
                title = card.get('title', card.get('cardId', card.get('id', '?')))
                for field in ['text', 'reflection', 'prompt']:
                    if field in card and card[field] and isinstance(card[field], str):
                        card[field] = fix_text(card[field], title)
                if 'bullets' in card and card['bullets']:
                    card['bullets'] = [
                        fix_text(b, title) if isinstance(b, str) else b
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
        basename = os.path.basename(f)
        if not any(basename.startswith(p) for p in ['singles_', 'married_', 'divorced_', 'widowed_']):
            continue
        total += 1
        change_details.clear()
        if process_file(f):
            print(f"+ {basename}")
            for d in change_details:
                print(d)
        else:
            print(f". {basename}")

    print(f"\n=== Done: {changes}/{total} modified ===")


if __name__ == '__main__':
    main()

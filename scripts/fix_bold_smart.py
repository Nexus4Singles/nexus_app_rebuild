#!/usr/bin/env python3
"""
Smart Bold Fixer: Properly balance ** markers in all journey files.

Strategy:
1. Parse text and find all ** marker positions
2. Pair them left-to-right
3. If a pair wraps too much text (>100 chars crossing \n\n), split it
4. If unpaired marker found, determine if it opens a label and close it,
   or remove it if it's a stray
"""

import json
import os
import re
import glob

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")


def is_label_pattern(text_after_marker):
    """Check if text after ** looks like a label that should be bold."""
    # Labels: "Step 1:", "Security:", "For yellow flags:", "Lies,", "Omission."
    # Look for: short text ending in : or . or , within ~60 chars
    m = re.match(r'^([^*\n]{1,60}?)([.:,])', text_after_marker)
    if m:
        return m.end()
    return None


def fix_bold_markers(text):
    """Fix unpaired ** markers in text."""
    if not text or '**' not in text:
        return text

    markers = [(m.start(), m.end()) for m in re.finditer(r'\*\*', text)]
    if len(markers) % 2 == 0:
        # Even count - check if any pair wraps across \n\n (too long)
        # This is acceptable for now
        return text

    # Odd count - need to fix
    # Strategy: go through each marker, determine if it's an opener or closer
    # Build new text with proper pairing

    result = []
    pos = 0
    i = 0

    while i < len(markers):
        start, end = markers[i]

        # Text before this marker
        result.append(text[pos:start])

        if i + 1 < len(markers):
            # There's a next marker - this is an opener, next is closer
            next_start, next_end = markers[i + 1]
            bold_content = text[end:next_start]

            # Check if this pair is reasonable
            if '\n\n' not in bold_content or len(bold_content) < 100:
                # Reasonable bold span
                result.append('**')
                result.append(bold_content)
                result.append('**')
                pos = next_end
                i += 2
            else:
                # Bold span crosses paragraphs - probably broken
                # This ** is likely an opener for a label
                label_end = is_label_pattern(text[end:])
                if label_end:
                    # Close bold after the label
                    result.append('**')
                    result.append(text[end:end + label_end])
                    result.append('**')
                    pos = end + label_end
                    i += 1  # Don't consume the next marker
                else:
                    # Can't determine - just keep the ** and move on
                    result.append('**')
                    pos = end
                    i += 1
        else:
            # This is the last (unpaired) marker
            # It's an opener without a closer
            label_end = is_label_pattern(text[end:])
            if label_end:
                # Close bold after the label
                result.append('**')
                result.append(text[end:end + label_end])
                result.append('**')
                pos = end + label_end
            else:
                # Try to close at next period, colon, or newline
                rest = text[end:]
                m = re.search(r'[.:]\s', rest)
                if m and m.start() < 80:
                    close_at = m.start() + 1  # include the punctuation
                    result.append('**')
                    result.append(text[end:end + close_at])
                    result.append('**')
                    pos = end + close_at
                else:
                    # Just remove the stray **
                    pos = end
            i += 1

    # Remaining text after last marker
    result.append(text[pos:])

    fixed = ''.join(result)

    # Verify we now have even count
    new_count = len(re.findall(r'\*\*', fixed))
    if new_count % 2 != 0:
        # Still odd - fall back to removing the last **
        # Find last ** and remove it
        last_pos = fixed.rfind('**')
        if last_pos >= 0:
            fixed = fixed[:last_pos] + fixed[last_pos + 2:]

    return fixed


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    original = json.dumps(data, ensure_ascii=False)
    fixed_count = 0

    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for card in activity.get('cards', []):
                for field in ['text', 'reflection', 'prompt']:
                    val = card.get(field, '')
                    if not val or not isinstance(val, str) or '**' not in val:
                        continue
                    count = len(re.findall(r'\*\*', val))
                    if count % 2 != 0:
                        fixed = fix_bold_markers(val)
                        if fixed != val:
                            card[field] = fixed
                            fixed_count += 1

    updated = json.dumps(data, ensure_ascii=False)
    if original != updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        return fixed_count
    return 0


def main():
    total_files = 0
    modified_files = 0
    total_fixed = 0

    for f in sorted(glob.glob(os.path.join(JOURNEYS_DIR, '**/*.json'), recursive=True)):
        bn = os.path.basename(f)
        if not any(bn.startswith(p) for p in ['singles_', 'married_', 'divorced_', 'widowed_']):
            continue
        total_files += 1
        fixed = process_file(f)
        if fixed > 0:
            modified_files += 1
            total_fixed += fixed
            print(f'+ {bn} ({fixed} cards fixed)')

    print(f'\n=== Done: {modified_files}/{total_files} files, {total_fixed} cards fixed ===')


if __name__ == '__main__':
    main()

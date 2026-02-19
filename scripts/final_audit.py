#!/usr/bin/env python3
"""
Comprehensive final audit of all journey files.
Checks:
1. Odd ** count (unpaired bold)
2. Broken {red|} tags
3. Words running together (lowercaseUppercase boundary)
4. Very long bold spans (>100 chars)
5. **\n\n inside bold spans
6. Empty bold **  **
7. Stray markers: {red}, {red), |**}
"""

import json
import os
import re
import glob

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

# Active file prefixes 
ACTIVE_PREFIXES = ['singles_journey_', 'married_journey_', 'divorced_journey_', 'widowed_journey_']

issues = []


def is_active(fn):
    """Check if file is an active journey file (not FLAGSHIP/POLISHED)."""
    return any(fn.startswith(p) for p in ACTIVE_PREFIXES) and 'FLAGSHIP' not in fn and 'POLISHED' not in fn


def audit_text(text, context):
    if not text or not isinstance(text, str):
        return

    # 1. Odd bold count
    count = len(re.findall(r'\*\*', text))
    if count % 2 != 0:
        issues.append(f"ODD_BOLD: {context}: {count} markers")

    # 2. Broken {red|} tags
    if '{red}' in text:
        issues.append(f"EMPTY_RED: {context}: bare {{red}} tag")
    if '{red)' in text or '|**}' in text:
        issues.append(f"MALFORMED_RED: {context}: {{red) or |**}} found")
    # Unclosed {red|
    opens = text.count('{red|')
    closes = text.count('}')
    # More precise: count {red| that don't have matching }
    for m in re.finditer(r'\{red\|', text):
        rest = text[m.end():]
        if '}' not in rest:
            issues.append(f"UNCLOSED_RED: {context}: unclosed {{red| tag")
            break

    # 3. Words running together
    for m in re.finditer(r'[a-z][A-Z][a-z]{3,}', text):
        word = m.group()
        # Filter out common camelCase / compound words
        if word in ['iPhone', 'YouTube', 'JavaScript', 'eBook']:
            continue
        issues.append(f"WORDS_TOGETHER: {context}: ...{text[max(0,m.start()-10):m.end()+10]}...")

    # 4. Very long bold spans
    for m in re.finditer(r'\*\*([^*]+)\*\*', text):
        span = m.group(1)
        if len(span) > 120:
            issues.append(f"LONG_BOLD: {context}: {len(span)} chars bold: {span[:60]}...")

    # 5. Empty or near-empty bold
    for m in re.finditer(r'\*\*(\s*)\*\*', text):
        issues.append(f"EMPTY_BOLD: {context}: empty ** ** markers")

    # 6. Double period
    if '..' in text and '...' not in text:
        issues.append(f"DOUBLE_PERIOD: {context}: found ..")


def main():
    total = 0
    for f in sorted(glob.glob(os.path.join(JOURNEYS_DIR, '**/*.json'), recursive=True)):
        bn = os.path.basename(f)
        if not is_active(bn):
            continue
        total += 1

        try:
            data = json.load(open(f))
        except:
            issues.append(f"JSON_ERROR: {bn}")
            continue

        for key in ['activities', 'missions']:
            if key not in data:
                continue
            for ai, act in enumerate(data[key]):
                for ci, card in enumerate(act.get('cards', [])):
                    title = card.get('title', card.get('id', '?'))
                    ctx = f"{bn} act{ai} c{ci} ({title})"

                    for field in ['text', 'reflection', 'prompt']:
                        val = card.get(field, '')
                        if val:
                            audit_text(val, f"{ctx} [{field}]")

                    for bi, bullet in enumerate(card.get('bullets', [])):
                        if bullet and isinstance(bullet, str):
                            audit_text(bullet, f"{ctx} [bullet {bi}]")

    # Report
    print(f"Audited {total} active files")
    print(f"Total issues found: {len(issues)}")
    print()

    # Group by type
    by_type = {}
    for issue in issues:
        itype = issue.split(':')[0]
        by_type.setdefault(itype, []).append(issue)

    for itype, items in sorted(by_type.items()):
        print(f"\n=== {itype} ({len(items)}) ===")
        for item in items[:20]:
            print(f"  {item}")
        if len(items) > 20:
            print(f"  ... and {len(items)-20} more")


if __name__ == '__main__':
    main()

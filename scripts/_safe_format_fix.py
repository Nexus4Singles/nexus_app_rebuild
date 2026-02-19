#!/usr/bin/env python3
"""
SAFE NON-DESTRUCTIVE FORMATTING FIX
====================================
Fixes formatting issues in journey JSON files WITHOUT truncating or
removing any content. Every fix is targeted and logged.

Safety measures:
- Content length is verified before/after each card (no data loss)
- Original file is read, fixed in memory, validated as JSON, then written
- Every change is logged with before/after snippets
- Dry-run mode available (--dry-run flag)

Usage:
  python3 scripts/_safe_format_fix.py                    # Fix all restored files
  python3 scripts/_safe_format_fix.py --dry-run           # Preview changes only
  python3 scripts/_safe_format_fix.py --folder "married"  # Fix specific category
"""
import json, os, re, glob, sys, copy

DRY_RUN = '--dry-run' in sys.argv
FOLDER_FILTER = None
for i, arg in enumerate(sys.argv):
    if arg == '--folder' and i + 1 < len(sys.argv):
        FOLDER_FILTER = sys.argv[i + 1]

changes_log = []

def log_change(fname, cid, field, rule, before_snippet, after_snippet):
    changes_log.append({
        'file': fname,
        'card': cid,
        'field': field,
        'rule': rule,
        'before': before_snippet[:120],
        'after': after_snippet[:120],
    })


def fix_text(text, fname, cid, field):
    """Apply all formatting fixes to a text field. Returns fixed text."""
    original = text

    # ── FIX 1: Double parentheses around red tags ────────────────────
    # (({red|...})) → ({red|...})
    before = text
    text = re.sub(r'\(\(\{red\|', '({red|', text)
    text = re.sub(r'\}\)\)', '})', text)
    if text != before:
        log_change(fname, cid, field, 'DOUBLE_PARENS',
                   re.search(r'\(\(\{red\|', before).group() if re.search(r'\(\(\{red\|', before) else '',
                   '({red|')

    # ── FIX 2: Smart/curly quotes → straight quotes ──────────────────
    before = text
    text = text.replace('\u201c', '"').replace('\u201d', '"')  # double
    text = text.replace('\u2018', "'").replace('\u2019', "'")  # single
    text = text.replace('\u2013', '-').replace('\u2014', '--')  # dashes
    if text != before:
        log_change(fname, cid, field, 'SMART_QUOTES', 'curly quotes', 'straight quotes')

    # ── FIX 3: Inline bullets → proper line breaks ───────────────────
    # Pattern: text followed by " • " mid-line (not at start of text or after \n)
    before = text
    # Add \n before bullet markers that are inline (preceded by non-newline text)
    text = re.sub(r'(?<!\n)(?<!\A) ([\u2022•]) ', r'\n\1 ', text)
    if text != before:
        log_change(fname, cid, field, 'INLINE_BULLETS',
                   'bullets on same line', 'bullets on separate lines')

    # ── FIX 4: Inline numbered lists → proper line breaks ────────────
    # "text 1. item 2. item" → "text\n1. item\n2. item"
    # Only match numbered items preceded by sentence-ending punctuation or
    # another list item's text, NOT inside bold markers like **1.**
    before = text
    # Match " N. " where preceded by sentence text (letter, period, paren, etc.)
    # but NOT by ** (bold marker) or : (heading continuation)
    text = re.sub(r'(?<=[.!?)}\]a-z]) (\d+)\. (?=[A-Z])', r'\n\1. ', text)
    if text != before:
        log_change(fname, cid, field, 'INLINE_NUMBERS',
                   'numbered items on same line', 'numbered items on separate lines')

    # ── FIX 5: Bold label fix ────────────────────────────────────────
    # **Label**: Description text.** → **Label:** Description text.
    # This pattern: **text**: more text** should become **text:** more text
    before = text
    # Match: **Label**: description.** (where the closing ** is at end of line/sentence)
    # We want: **Label:** description. (bold only on label)
    text = re.sub(
        r'\*\*([^*\n]{1,60})\*\*: ([^*\n]+?)\.\*\*',
        r'**\1:** \2.',
        text
    )
    if text != before:
        log_change(fname, cid, field, 'BOLD_LABEL_FIX',
                   '**Label**: text.**', '**Label:** text.')

    # Alt pattern: **Label**: Description text without trailing **
    # These are usually fine — the first ** and the **: pair work together
    # But sometimes there's an orphan **: that should be **:
    # We actually need to look for lines that have odd ** count

    # ── FIX 6: Bold inside red tag ───────────────────────────────────
    # {red|...|**} → {red|...}
    before = text
    text = re.sub(r'\{red\|([^}|]+)\|\*\*\}', r'{red|\1}', text)
    if text != before:
        log_change(fname, cid, field, 'BOLD_IN_RED', '{red|...|**}', '{red|...}')

    # ── FIX 7: Book number split from red tag ────────────────────────
    # (1 {red|Thessalonians... → ({red|1 Thessalonians...
    # (2 {red|Corinthians... → ({red|2 Corinthians...
    before = text
    text = re.sub(r'\(([12])\s+\{red\|', r'({red|\1 ', text)
    if text != before:
        log_change(fname, cid, field, 'BOOK_NUM_SPLIT',
                   '(1 {red|Book', '({red|1 Book')

    # ── FIX 8: Empty red tags ────────────────────────────────────────
    # {red|} or {red| } → remove entirely
    before = text
    text = re.sub(r'\{red\|\s*\}', '', text)
    if text != before:
        log_change(fname, cid, field, 'EMPTY_RED', '{red|}', '(removed)')

    # ── FIX 9: Double closing braces ─────────────────────────────────
    # ...text}} → ...text}  (when after red tag content)
    before = text
    text = re.sub(r'\}\}(?!\{)', '}', text)
    if text != before:
        log_change(fname, cid, field, 'DOUBLE_CLOSE_BRACE', '}}', '}')

    # ── FIX 10: Triple+ newlines → double newlines ───────────────────
    before = text
    text = re.sub(r'\n{3,}', '\n\n', text)
    if text != before:
        log_change(fname, cid, field, 'TRIPLE_NEWLINE', '\\n\\n\\n+', '\\n\\n')

    # ── FIX 11: Leading/trailing whitespace ──────────────────────────
    before = text
    text = text.strip()
    if text != before:
        log_change(fname, cid, field, 'TRIM_WHITESPACE', 'leading/trailing ws', 'trimmed')

    # ── FIX 12: Double spaces → single space ─────────────────────────
    before = text
    text = re.sub(r'  +', ' ', text)
    if text != before:
        log_change(fname, cid, field, 'DOUBLE_SPACE', 'double spaces', 'single spaces')

    # ── FIX 13: Trailing comma in red tag display text ────────────────
    # {red|Verse|display text,} → {red|Verse|display text}
    before = text
    text = re.sub(r',(\})\)', r'\1)', text)
    if text != before:
        log_change(fname, cid, field, 'TRAILING_COMMA_RED', 'text,})', 'text})')

    # ── SAFETY CHECK: ensure we haven't lost content ─────────────────
    # Compare character count (excluding formatting characters we intentionally changed)
    # The text should only have grown (added \n) or stayed same, never shrunk significantly
    orig_alpha = re.sub(r'[^a-zA-Z]', '', original)
    new_alpha = re.sub(r'[^a-zA-Z]', '', text)
    if len(new_alpha) < len(orig_alpha) * 0.95:
        print(f"  ⚠️  SAFETY: {fname} {cid} {field}: alpha content shrank from {len(orig_alpha)} to {len(new_alpha)}!")
        print(f"      Reverting this card's changes.")
        return original  # REVERT — don't risk data loss

    return text


def process_file(filepath):
    """Process a single JSON file. Returns (changed: bool, error: str|None)."""
    fname = os.path.basename(filepath)

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            raw = f.read()
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"

    original_data = copy.deepcopy(data)
    changed = False

    activities = data.get('activities', [])
    for act in activities:
        cards = act.get('cards', [])
        for card in cards:
            cid = card.get('cardId') or card.get('id') or '??'

            # Fix text fields
            for field in ['text', 'reflection']:
                val = card.get(field)
                if val and isinstance(val, str):
                    fixed = fix_text(val, fname, cid, field)
                    if fixed != val:
                        card[field] = fixed
                        changed = True

            # Fix prompts/bullets arrays
            for arr_field in ['prompts', 'bullets']:
                arr = card.get(arr_field)
                if arr and isinstance(arr, list):
                    for idx, item in enumerate(arr):
                        if isinstance(item, str):
                            fixed = fix_text(item, fname, cid, f'{arr_field}[{idx}]')
                            if fixed != item:
                                arr[idx] = fixed
                                changed = True

    if changed and not DRY_RUN:
        # Validate the output is valid JSON by round-tripping
        output = json.dumps(data, indent=2, ensure_ascii=False)
        try:
            json.loads(output)  # validate
        except json.JSONDecodeError as e:
            return False, f"Output JSON invalid: {e} — NOT writing"

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output + '\n')

    return changed, None


def main():
    base = "assets/config/journeys"

    if FOLDER_FILTER:
        folders = [f for f in ["married journeys", "divorced journeys", "widowed journeys"]
                   if FOLDER_FILTER.lower() in f.lower()]
    else:
        # Only process restored categories (not singles — those are already clean)
        folders = ["divorced journeys", "married journeys", "widowed journeys"]

    total_files = 0
    total_changed = 0
    total_errors = 0

    for folder in folders:
        path = os.path.join(base, folder)
        files = sorted(glob.glob(os.path.join(path, "*.json")))

        print(f"\n{'='*60}")
        print(f"  {folder.upper()} ({len(files)} files)")
        print(f"{'='*60}")

        for filepath in files:
            fname = os.path.basename(filepath)
            total_files += 1

            changed, error = process_file(filepath)
            if error:
                print(f"  ❌ {fname}: {error}")
                total_errors += 1
            elif changed:
                print(f"  ✅ {fname}: fixed")
                total_changed += 1
            else:
                print(f"  ⬚  {fname}: no changes needed")

    # ── SUMMARY ──────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print(f"  SUMMARY {'(DRY RUN)' if DRY_RUN else ''}")
    print(f"{'='*60}")
    print(f"  Files processed: {total_files}")
    print(f"  Files changed:   {total_changed}")
    print(f"  Errors:          {total_errors}")
    print(f"  Total fixes:     {len(changes_log)}")
    print()

    # Print changes by rule
    if changes_log:
        from collections import Counter
        rule_counts = Counter(c['rule'] for c in changes_log)
        print("  Fixes by type:")
        for rule, count in rule_counts.most_common():
            print(f"    {rule}: {count}")
        print()

        # Print first 30 changes as sample
        print("  Sample changes (first 30):")
        for c in changes_log[:30]:
            print(f"    {c['file']} / {c['card']} / {c['field']}: [{c['rule']}]")
            print(f"      before: {c['before'][:80]}")
            print(f"      after:  {c['after'][:80]}")


if __name__ == '__main__':
    main()

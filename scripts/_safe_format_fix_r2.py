#!/usr/bin/env python3
"""
ROUND 2: Fix nested red tags, orphan braces, and broken bold markers.
Non-destructive — preserves all content, logs every change.
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
        'file': fname, 'card': cid, 'field': field,
        'rule': rule,
        'before': before_snippet[:120],
        'after': after_snippet[:120],
    })


def remove_outer_red_wrappers(text):
    """
    Remove outer {red|...} wrappers that contain inner {red|...} tags.
    The renderer can't handle nesting, so the outer wrapper must go.
    
    Strategy: find each {red| opener, determine its "intended" closing }
    by tracking brace depth. If it spans inner {red|} tags, remove
    just the outer {red| and its closing }.
    """
    result = []
    i = 0
    changed = False
    
    while i < len(text):
        # Check for {red| at current position
        if text[i:i+5] == '{red|':
            # Find the matching } for this {red| by tracking depth
            depth = 0
            j = i + 5  # start after {red|
            has_inner_red = False
            close_pos = None
            
            while j < len(text):
                if text[j:j+5] == '{red|':
                    has_inner_red = True
                    depth += 1
                    j += 5
                    continue
                elif text[j] == '}':
                    if depth == 0:
                        close_pos = j
                        break
                    depth -= 1
                j += 1
            
            if has_inner_red and close_pos is not None:
                # This is a nested situation — remove outer {red| and its closing }
                # Keep everything between them as-is
                inner_content = text[i+5:close_pos]
                result.append(inner_content)
                i = close_pos + 1
                changed = True
                continue
        
        result.append(text[i])
        i += 1
    
    return ''.join(result), changed


def fix_text_r2(text, fname, cid, field):
    """Apply Round 2 fixes."""
    original = text

    # ── FIX R2-1: Remove outer {red|} wrappers with nested inner tags ─
    before = text
    text, did_change = remove_outer_red_wrappers(text)
    if did_change:
        log_change(fname, cid, field, 'NESTED_RED_UNWRAP',
                   'nested {red| removed outer wrapper',
                   'outer {red|} removed, inner kept')

    # ── FIX R2-2: Orphan closing } not part of any {red|} ───────────
    before = text
    # After removing outer wrappers, check for orphan }
    stripped = re.sub(r'\{red\|[^}]*\}', '', text, flags=re.DOTALL)
    if '}' in stripped and '{' not in stripped:
        # There are orphan } — remove them carefully
        # Only remove } that are NOT part of a {red|..} tag
        new_text = []
        in_red = False
        k = 0
        while k < len(text):
            if text[k:k+5] == '{red|':
                in_red = True
                new_text.append(text[k:k+5])
                k += 5
                continue
            if text[k] == '}' and in_red:
                new_text.append('}')
                in_red = False
                k += 1
                continue
            if text[k] == '}' and not in_red:
                # Orphan } — skip it
                k += 1
                continue
            new_text.append(text[k])
            k += 1
        text = ''.join(new_text)
    if text != before:
        log_change(fname, cid, field, 'ORPHAN_BRACE_REMOVE',
                   'orphan } removed', 'clean text')

    # ── FIX R2-3: Per-paragraph stray ** removal ───────────────────
    # For each paragraph that has an ODD number of ** markers,
    # find and remove the stray one (typically a trailing .** on a description)
    before = text
    paras = text.split('\n')
    fixed_paras = []
    for para in paras:
        if not para.strip():
            fixed_paras.append(para)
            continue
        # Strip {red|...} to count ** outside tags
        test = re.sub(r'\{red\|[^}]*\}', 'REDTAG', para)
        star_count = test.count('**')
        if star_count % 2 != 0 and star_count >= 3:
            # Odd count with at least 3 markers.
            # Common pattern: **Label** description.** → remove the trailing .**
            # The trailing .** is a stray close that has no opener
            # Only remove .** that follows non-bold text (after a matched ** pair)
            # Find the pattern: first ** pair is matched, then trailing .**
            m = re.match(r'^(.*\*\*[^*\n]+\*\*[^*\n]+)\.\*\*(.*)$', para)
            if m:
                para = m.group(1) + '.' + m.group(2)
        elif star_count == 1:
            # Single stray ** — often a closing .** without an opener
            # Pattern: "description text.**" → "description text."
            # Or: "**Opening text:" → close it: "**Opening text:**"
            # Only handle the .** case (safe removal)
            if re.search(r'[^*]\.\*\*["\']?$', para):
                para = re.sub(r'\.\*\*(["\']?)$', r'.\1', para)
        fixed_paras.append(para)
    text = '\n'.join(fixed_paras)
    if text != before:
        log_change(fname, cid, field, 'STRAY_BOLD_FIX',
                   'odd ** in paragraph', 'stray ** removed')

    # ── FIX R2-4: .**'** → .'** pattern ─────────────────────────────
    # "**'You're worth my effort.**'**" → "**'You're worth my effort.'**"
    before = text
    text = re.sub(r"\*\*'([^'*]+)\.\*\*'\*\*", r"**'\1.'**", text)
    if text != before:
        log_change(fname, cid, field, 'BOLD_QUOTE_FIX',
                   ".**'**", ".'**")

    # ── FIX R2-5: Bold glued to next word: **text**Word → **text** Word ─
    before = text
    text = re.sub(r'\*\*([^*\n]{1,40})\*\*([A-Z])', r'**\1** \2', text)
    if text != before:
        log_change(fname, cid, field, 'BOLD_GLUED_FIX',
                   '**text**Word', '**text** Word')

    # ── FIX R2-6: Bold split across line (open ** on one line, close on another)
    # Pattern: "**Text that opens:\n• bullet.** closes here"
    # Fix: close bold before newline, reopen after
    # This is complex — let's handle the most common sub-pattern:
    # A line starting with ** but no closing ** on that line
    # followed by a bullet or numbered item line that has a closing **
    before = text
    lines = text.split('\n')
    fixed_lines = []
    i_line = 0
    while i_line < len(lines):
        line = lines[i_line]
        stripped_line = re.sub(r'\{red\|[^}]*\}', 'REDTAG', line)
        star_count = stripped_line.count('**')
        
        if star_count % 2 != 0:
            # This line has odd ** count
            # Check if it starts with ** (opening) and has no close
            if stripped_line.strip().startswith('**') and star_count == 1:
                # Open bold on this line with no close
                # Close it at end of line, before any trailing punctuation
                line = line.rstrip()
                if line.endswith(':'):
                    line = line[:-1] + ':**'
                    line = line.replace('**' + line.lstrip('**').split('**')[0], 
                                        '**' + line.lstrip('**').split('**')[0], 1)
                    # Actually simpler: just add ** before the colon
                    pass  # This is getting too complex, skip for safety
            
            # Check if the stray ** is at end of line as .**
            # "talking.** They need" → odd. Remove the .**
            # Already handled by R2-3 above
            pass
        
        fixed_lines.append(lines[i_line])
        i_line += 1
    # Don't apply line-level bold fix — too risky for automation
    # text = '\n'.join(fixed_lines)

    # ── FIX R2-7: Fragmented {red| tags in widowed files ────────────
    # Only join }{red| boundaries that split a single sentence/quote
    # Pattern: "word}{red| word" where the text flows as one sentence
    # e.g., "How long, O Lord?}{red| Will you forget me forever?}"
    # Do NOT join if followed by ( which indicates a scripture ref
    before = text
    text = re.sub(r'\}\{red\| (?!\()', ' ', text)
    if text != before:
        log_change(fname, cid, field, 'FRAG_RED_JOIN',
                   '}{red| ', ' (joined fragments)')

    # ── FIX R2-8: Clean up {red|" at start ─────────────────────────
    # Skip — moving quotes outside {red| tags could break rendering intent

    # ── SAFETY CHECK ─────────────────────────────────────────────────
    orig_alpha = re.sub(r'[^a-zA-Z]', '', original)
    new_alpha = re.sub(r'[^a-zA-Z]', '', text)
    if len(new_alpha) < len(orig_alpha) * 0.95:
        print(f"  ⚠️  SAFETY: {fname} {cid} {field}: alpha shrank {len(orig_alpha)}→{len(new_alpha)}!")
        return original
    
    return text


def process_file(filepath):
    fname = os.path.basename(filepath)
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"

    changed = False
    for act in data.get('activities', []):
        for card in act.get('cards', []):
            cid = card.get('cardId') or card.get('id') or '??'
            for field in ['text', 'reflection']:
                val = card.get(field)
                if val and isinstance(val, str):
                    fixed = fix_text_r2(val, fname, cid, field)
                    if fixed != val:
                        card[field] = fixed
                        changed = True
            for arr_field in ['prompts', 'bullets']:
                arr = card.get(arr_field)
                if arr and isinstance(arr, list):
                    for idx, item in enumerate(arr):
                        if isinstance(item, str):
                            fixed = fix_text_r2(item, fname, cid, f'{arr_field}[{idx}]')
                            if fixed != item:
                                arr[idx] = fixed
                                changed = True

    if changed and not DRY_RUN:
        output = json.dumps(data, indent=2, ensure_ascii=False)
        try:
            json.loads(output)
        except json.JSONDecodeError as e:
            return False, f"Output invalid: {e}"
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(output + '\n')

    return changed, None


def main():
    base = "assets/config/journeys"
    if FOLDER_FILTER:
        folders = [f for f in ["married journeys", "divorced journeys", "widowed journeys"]
                   if FOLDER_FILTER.lower() in f.lower()]
    else:
        folders = ["divorced journeys", "married journeys", "widowed journeys"]

    total_files = total_changed = total_errors = 0
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

    print(f"\n{'='*60}")
    print(f"  ROUND 2 SUMMARY {'(DRY RUN)' if DRY_RUN else ''}")
    print(f"{'='*60}")
    print(f"  Files processed: {total_files}")
    print(f"  Files changed:   {total_changed}")
    print(f"  Errors:          {total_errors}")
    print(f"  Total fixes:     {len(changes_log)}")
    print()
    if changes_log:
        from collections import Counter
        rule_counts = Counter(c['rule'] for c in changes_log)
        print("  Fixes by type:")
        for rule, count in rule_counts.most_common():
            print(f"    {rule}: {count}")
        print()
        print("  Sample changes (first 20):")
        for c in changes_log[:20]:
            print(f"    {c['file']} / {c['card']} / {c['field']}: [{c['rule']}]")
            print(f"      before: {c['before'][:80]}")
            print(f"      after:  {c['after'][:80]}")


if __name__ == '__main__':
    main()

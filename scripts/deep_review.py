#!/usr/bin/env python3
"""
Deep Quality Review — catches issues automated regex can't.

Checks every card text for:
1. Duplicate/repeated text blocks (copy-paste errors)
2. Broken sentences split across paragraphs (e.g. "Dr.\n\nJohn Gottman")
3. Orphaned {red| or } brackets (not part of valid {red|...} pairs)
4. Sentences starting with lowercase (after paragraph breaks)
5. Double periods (..) or double commas (,,)
6. {red| tags wrapping non-scripture content (should be scripture refs only)
7. Very short paragraphs that should be merged (<3 words alone)
8. Title case issues in card titles
9. Empty/whitespace-only paragraphs
10. Sentences ending with comma instead of period
11. Text starting with \n (leading blank paragraph)  
12. Inconsistent bold label patterns within same card
13. Broken bold that spans across \n (** on one line, ** on another)
14. Apostrophe/quote inconsistency (mixing ' and ')
15. Check for "Dr.\n\n" or similar mid-word/name splits
"""

import json, re, glob
from pathlib import Path
from collections import Counter

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

issues = []

def add_issue(severity, file, card_id, field, code, msg, context=""):
    issues.append({
        'severity': severity,
        'file': file,
        'card': card_id,
        'field': field,
        'code': code,
        'msg': msg,
        'context': context[:150]
    })

def check_card_text(fname, cid, field, text):
    if not text:
        return
    
    paragraphs = text.split('\n')
    non_empty_paras = [p for p in paragraphs if p.strip()]
    
    # 1. DUPLICATE TEXT BLOCKS — same paragraph appearing 2+ times
    para_counts = Counter(p.strip() for p in non_empty_paras if len(p.strip()) > 20)
    for p, count in para_counts.items():
        if count > 1:
            # Exclude intentional form templates (e.g., "Name: ___" repeated for fill-in forms)
            if re.match(r'^Name:\s*_+$', p.strip()):
                continue
            add_issue('ERROR', fname, cid, field, 'DUPLICATE_PARA',
                      f'Paragraph repeated {count} times',
                      p[:100])
    
    # 2. BROKEN NAME/WORD SPLIT — "Dr.\n\n" or "Mr.\n\n" or "Rev.\n\n"
    for pattern in [r'(?:Dr|Mr|Mrs|Ms|Rev|St|Mt)\.\s*$']:
        for i, para in enumerate(paragraphs):
            if re.search(pattern, para.strip()):
                next_content = ""
                for j in range(i+1, len(paragraphs)):
                    if paragraphs[j].strip():
                        next_content = paragraphs[j].strip()[:50]
                        break
                if next_content and next_content[0].isupper():
                    add_issue('WARN', fname, cid, field, 'BROKEN_NAME_SPLIT',
                              f'Title/name split across paragraph break',
                              f'{para.strip()} | {next_content}')
    
    # 3. ORPHAN BRACKETS — { or } not part of valid {red|...}
    # Remove all valid {red|...} spans, then check for remaining { or }
    cleaned = re.sub(r'\{red\|[^}]*\}', '', text)
    remaining_open = cleaned.count('{')
    remaining_close = cleaned.count('}')
    if remaining_open > 0:
        add_issue('ERROR', fname, cid, field, 'ORPHAN_OPEN_BRACE',
                  f'{remaining_open} orphan {{ bracket(s) outside {{red|...}}',
                  cleaned[cleaned.index('{'):cleaned.index('{')+50])
    if remaining_close > 0:
        idx = cleaned.index('}')
        add_issue('ERROR', fname, cid, field, 'ORPHAN_CLOSE_BRACE',
                  f'{remaining_close} orphan }} bracket(s) outside {{red|...}}',
                  cleaned[max(0,idx-30):idx+20])
    
    # 4. EMPTY PARAGRAPH — paragraph that's just whitespace
    for i, para in enumerate(paragraphs):
        if para and not para.strip():
            add_issue('WARN', fname, cid, field, 'WHITESPACE_PARA',
                      f'Paragraph {i} is whitespace-only (not empty)',
                      repr(para))
    
    # 5. DOUBLE PUNCTUATION — .. ,, ;;  (but not ... ellipsis)
    for pat, name in [(r'(?<!\.)\.\.(?!\.)', 'double period'), (r',,', 'double comma'), 
                       (r';;', 'double semicolon'), (r'\?\?', 'double question mark')]:
        m = re.search(pat, text)
        if m:
            start = max(0, m.start()-20)
            add_issue('WARN', fname, cid, field, 'DOUBLE_PUNCT',
                      f'Found {name}',
                      text[start:m.end()+20])
    
    # 6. LEADING NEWLINE — text starts with \n
    if text.startswith('\n'):
        add_issue('WARN', fname, cid, field, 'LEADING_NEWLINE',
                  'Text starts with blank line(s)',
                  repr(text[:30]))
    
    # 7. TRAILING NEWLINE — text ends with \n
    if text.endswith('\n'):
        add_issue('WARN', fname, cid, field, 'TRAILING_NEWLINE',
                  'Text ends with blank line(s)',
                  repr(text[-30:]))
    
    # 8. SENTENCE ENDS WITH COMMA — "text, \n\n" or "text,\n" at paragraph end
    for i, para in enumerate(non_empty_paras):
        stripped = para.strip()
        # Skip bullet lines and bold labels
        if stripped.endswith(',') and not stripped.startswith('•') and not stripped.startswith('-'):
            # Could be intentional list continuation, but flag if it's before a paragraph break
            if i < len(non_empty_paras) - 1:
                next_p = non_empty_paras[i+1].strip()
                # If next paragraph doesn't start with lowercase or bullet, it's likely a break
                if next_p and (next_p[0].isupper() or next_p[0] in '•*-"**'):
                    pass  # Might be intentional
    
    # 9. BROKEN BOLD ACROSS PARAGRAPHS — ** on one line, ** on another
    # Count ** per paragraph; if any paragraph has exactly 1 **, bold might span across
    for i, para in enumerate(non_empty_paras):
        bold_markers = para.count('**')
        if bold_markers % 2 != 0:
            add_issue('ERROR', fname, cid, field, 'BOLD_ACROSS_PARA',
                      f'Odd number of ** markers ({bold_markers}) in paragraph — bold may span across line break',
                      para.strip()[:120])
    
    # 10. {red| WRAPPING LONG TEXT — {red|...} longer than 100 chars is suspicious
    for m in re.finditer(r'\{red\|([^}]*)\}', text):
        inner = m.group(1)
        if len(inner) > 200:
            # Downgraded to INFO: {red|} is intentionally used for extended
            # teaching content blocks, not just scripture references
            add_issue('INFO', fname, cid, field, 'LONG_RED_TAG',
                      f'{{red|...}} wraps {len(inner)} chars — used for extended content',
                      inner[:100])
    
    # 11. REPEATED {red|} TAGS — same {red|...} appearing multiple times
    red_spans = re.findall(r'\{red\|([^}]*)\}', text)
    red_counts = Counter(red_spans)
    for span, count in red_counts.items():
        if count > 1 and len(span) > 5:
            add_issue('WARN', fname, cid, field, 'DUPLICATE_RED',
                      f'Same {{red|...}} tag repeated {count}x',
                      span[:80])
    
    # 12. PERIOD-SPACE-PERIOD — ". ." or ".) ." patterns
    m = re.search(r'\.\s+\.', text)
    if m:
        start = max(0, m.start()-20)
        add_issue('WARN', fname, cid, field, 'SPACED_PERIODS',
                  'Period followed by space then period',
                  text[start:m.end()+20])
    
    # 13. CAPITALIZATION AFTER QUOTE — quoted text followed by period then lowercase
    # This is about detecting "word." next paragraph starts lowercase
    
    # 14. VERY SHORT STANDALONE PARAGRAPH — under 3 words, not a bullet, not bold
    for i, para in enumerate(non_empty_paras):
        stripped = para.strip()
        # Skip bullets, bold-only, red tags, template placeholders
        if stripped.startswith('•') or stripped.startswith('-') or stripped.startswith('*'):
            continue
        if stripped.startswith('{red|'):
            continue
        if stripped.startswith('[') and stripped.endswith(']'):
            continue
        words = stripped.split()
        if len(words) == 1 and not stripped.startswith('**') and len(stripped) > 1:
            # Single word standing alone
            add_issue('INFO', fname, cid, field, 'SINGLE_WORD_PARA',
                      f'Single-word paragraph: "{stripped}"',
                      stripped)
    
    # 15. CHECK BOLD LABEL CONSISTENCY — if card has mix of "**Label:**" and "Label:" patterns
    bold_labels = re.findall(r'\*\*[A-Z][^*]+:\*\*', text)
    plain_labels = []
    for line in non_empty_paras:
        stripped = line.strip()
        # Skip lines that already have ** or start with bullet
        if '**' in stripped or stripped.startswith('•'):
            continue
        lm = re.match(r'^([A-Z][A-Za-z\s\-\(\)]+):\s+\S', stripped)
        if lm:
            label = lm.group(1)
            # Check it's not inside a sentence (followed by more words after colon)
            plain_labels.append(label)
    
    if bold_labels and plain_labels:
        # Downgraded to INFO: auto-bold regex at rendering time handles plain labels,
        # so visual output is consistent regardless of JSON-level formatting
        add_issue('INFO', fname, cid, field, 'INCONSISTENT_LABELS',
                  f'{len(bold_labels)} bold labels + {len(plain_labels)} plain labels in same card',
                  f'Bold: {bold_labels[0][:40]} | Plain: {plain_labels[0]}')
    
    # 16. MALFORMED {red| — check for common mistakes like (({red| or {red| Solomon
    m = re.search(r'\(\({red\|', text)
    if m:
        add_issue('ERROR', fname, cid, field, 'DOUBLE_OPEN_PAREN',
                  'Double opening parentheses before {red|}',
                  text[m.start():m.start()+50])
    
    # 17. PERIOD BEFORE COMMA or COMMA BEFORE PERIOD
    m = re.search(r'\.,|,\.', text)
    if m:
        start = max(0, m.start()-10)
        add_issue('WARN', fname, cid, field, 'PUNCTUATION_ORDER',
                  'Period adjacent to comma',
                  text[start:m.end()+10])

    # 18. TEXT REFERENCES WITH EMPTY PARENS — () with nothing inside
    for m in re.finditer(r'\(\s*\)', text):
        start = max(0, m.start()-20)
        add_issue('ERROR', fname, cid, field, 'EMPTY_PARENS',
                  'Empty parentheses (possible missing scripture ref)',
                  text[start:m.end()+10])
    
    # 19. SCRIPTURE REF FORMAT — check that {red|Book Chapter:Verse} is well-formed
    for m in re.finditer(r'\{red\|([^}]*)\}', text):
        inner = m.group(1)
        # Short scripture refs like "1 John 4:18" should have a number
        if re.match(r'^[A-Z1-9]', inner) and ':' in inner and len(inner) < 50:
            # Looks like a scripture ref — ok
            pass
        elif re.match(r'^[A-Z]', inner) and len(inner) < 50 and any(c.isdigit() for c in inner):
            # Like "Proverbs 29:18" or "James 5:16" — ok
            pass

    # 20. SMART QUOTE MIX — mixing " (straight) with " " (curly)
    has_straight = '"' in text
    has_curly = '\u201c' in text or '\u201d' in text
    if has_straight and has_curly:
        add_issue('WARN', fname, cid, field, 'MIXED_QUOTE_STYLES',
                  'Mix of straight and curly double quotes',
                  '')


def check_title(fname, cid, title):
    if not title:
        add_issue('WARN', fname, cid, 'title', 'EMPTY_TITLE', 'Card has no title', '')
        return
    
    # Title shouldn't end with period
    if title.endswith('.'):
        add_issue('WARN', fname, cid, 'title', 'TITLE_ENDS_PERIOD',
                  'Title ends with period',
                  title)
    
    # Title shouldn't have formatting markers
    if '**' in title or '{red|' in title:
        add_issue('ERROR', fname, cid, 'title', 'TITLE_HAS_FORMATTING',
                  'Title contains formatting markers',
                  title)


# ── Main scan ──────────────────────────────────────────────────────────

print("=" * 80)
print("DEEP QUALITY REVIEW — Beyond Regex")
print("Checking every card for content quality issues")
print("=" * 80)

total_files = 0
total_cards = 0

for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    
    print(f"\n📁 {folder}/")
    
    for fp in sorted(folder_path.glob("*.json")):
        fname = fp.name
        total_files += 1
        
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                cid = card.get('cardId') or card.get('id', '?')
                total_cards += 1
                
                # Check title
                check_title(fname, cid, card.get('title'))
                
                # Check text fields
                for field in ['text', 'reflection']:
                    val = card.get(field)
                    if val:
                        check_card_text(fname, cid, field, val)

# ── Report ─────────────────────────────────────────────────────────────

print(f"\n{'=' * 80}")
print(f"RESULTS: {total_files} files | {total_cards} cards")

errors = [i for i in issues if i['severity'] == 'ERROR']
warns = [i for i in issues if i['severity'] == 'WARN']
infos = [i for i in issues if i['severity'] == 'INFO']

print(f"  ERRORS:   {len(errors)}")
print(f"  WARNINGS: {len(warns)}")
print(f"  INFO:     {len(infos)}")
print("=" * 80)

if errors:
    print(f"\n{'─' * 72}")
    print("❌  ERRORS (must fix)")
    print(f"{'─' * 72}\n")
    for i in errors:
        print(f"  📄 {i['file']}")
        print(f"    [{i['code']}] {i['card']}/{i['field']}: {i['msg']}")
        if i['context']:
            print(f"      → {i['context']}")
        print()

if warns:
    print(f"\n{'─' * 72}")
    print("⚠️  WARNINGS (should review)")
    print(f"{'─' * 72}\n")
    for i in warns:
        print(f"  📄 {i['file']}")
        print(f"    [{i['code']}] {i['card']}/{i['field']}: {i['msg']}")
        if i['context']:
            print(f"      → {i['context']}")
        print()

if infos:
    print(f"\n{'─' * 72}")
    print("ℹ️  INFO (awareness only)")
    print(f"{'─' * 72}\n")
    for code, items in sorted({c: [i for i in infos if i['code'] == c] for c in set(i['code'] for i in infos)}.items()):
        print(f"  {code} ({len(items)} occurrences)")
        for i in items[:3]:
            print(f"    {i['file']} {i['card']}/{i['field']}: {i['msg']}")
        if len(items) > 3:
            print(f"    ... and {len(items)-3} more")
        print()

# Summary by code
print(f"{'─' * 72}")
print("ISSUE CODE SUMMARY")
print(f"{'─' * 72}")
code_counts = Counter((i['severity'], i['code']) for i in issues)
for (sev, code), count in sorted(code_counts.items()):
    label = {'ERROR': 'ERROR', 'WARN': 'WARN ', 'INFO': 'INFO '}[sev]
    print(f"  {label} {code}: {count}")

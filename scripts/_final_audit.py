#!/usr/bin/env python3
"""
FINAL INDEPENDENT AUDIT — fresh eyes on all 65 journey JSON files.
Checks everything the rendering pipeline cares about.
"""
import json, os, re, glob, sys
from collections import Counter

issues = []

def add(sev, fname, loc, code, msg, snippet=""):
    issues.append((sev, fname, loc, code, msg, snippet[:120]))

# ─────────────────────────────────────────────────────────────────────
# CHECKS
# ─────────────────────────────────────────────────────────────────────

def check_json_structure(filepath, data, fname):
    """Validate top-level structure and required fields."""
    required_top = ['journeyId', 'title', 'activities']
    for key in required_top:
        if key not in data:
            add('ERROR', fname, 'root', 'MISSING_KEY', f'Missing required key: {key}')
    
    activities = data.get('activities', [])
    if not isinstance(activities, list):
        add('ERROR', fname, 'root', 'BAD_ACTIVITIES', 'activities is not a list')
        return
    
    for ai, act in enumerate(activities):
        cards = act.get('cards', [])
        if not isinstance(cards, list):
            add('ERROR', fname, f'act_{ai}', 'BAD_CARDS', 'cards is not a list')
            continue
        
        for ci, card in enumerate(cards):
            cid = card.get('cardId') or card.get('id') or f'card_{ci}'
            
            # Required card fields
            if 'cardType' not in card:
                add('ERROR', fname, cid, 'NO_CARD_TYPE', 'Missing cardType')
            if 'title' not in card:
                add('ERROR', fname, cid, 'NO_TITLE', 'Missing title')
            if 'text' not in card:
                add('WARN', fname, cid, 'NO_TEXT', 'Missing text field')
            
            # Check text fields
            for field in ['text', 'reflection']:
                val = card.get(field)
                if val and isinstance(val, str):
                    check_text(fname, cid, field, val)
            
            # Check title
            title = card.get('title', '')
            if title:
                check_title(fname, cid, title)
            
            # Check prompts/bullets arrays
            for arr_field in ['prompts', 'bullets']:
                arr = card.get(arr_field)
                if arr and isinstance(arr, list):
                    for idx, item in enumerate(arr):
                        if isinstance(item, str):
                            check_text(fname, cid, f'{arr_field}[{idx}]', item)

def check_title(fname, cid, title):
    """Check card title formatting."""
    # Title should not contain formatting markers
    if '{red|' in title:
        add('ERROR', fname, cid, 'TITLE_HAS_RED', 'Title contains {red|} tag', title)
    if '**' in title:
        add('WARN', fname, cid, 'TITLE_HAS_BOLD', 'Title contains ** bold markers', title)
    if title != title.strip():
        add('ERROR', fname, cid, 'TITLE_WHITESPACE', 'Title has leading/trailing whitespace', repr(title))

def check_text(fname, cid, field, text):
    """Comprehensive text field checks."""
    
    # ── 1. RED TAG INTEGRITY ─────────────────────────────────────────
    
    # 1a. Count {red| openers vs } closers within red context
    red_opens = [m.start() for m in re.finditer(r'\{red\|', text)]
    for pos in red_opens:
        # Find matching closing }
        depth = 0
        found_close = False
        for i in range(pos + 5, len(text)):
            if text[i] == '{':
                depth += 1
            elif text[i] == '}':
                if depth == 0:
                    found_close = True
                    break
                depth -= 1
        if not found_close:
            add('ERROR', fname, cid, 'UNCLOSED_RED',
                f'{field}: {{red| at pos {pos} has no matching }}',
                text[pos:pos+60])
    
    # 1b. Bare {red without pipe
    for m in re.finditer(r'\{red(?!\|)', text):
        add('ERROR', fname, cid, 'BARE_RED',
            f'{field}: bare {{red without | at pos {m.start()}',
            text[m.start():m.start()+30])
    
    # 1c. Wrong case/syntax
    for m in re.finditer(r'\{(Red|RED|rEd|reD)\|', text):
        add('ERROR', fname, cid, 'RED_CASE',
            f'{field}: wrong case {{{m.group(1)}|',
            m.group())
    
    # 1d. Empty red: {red|}  or  {red| }
    for m in re.finditer(r'\{red\|\s*\}', text):
        add('ERROR', fname, cid, 'EMPTY_RED',
            f'{field}: empty {{red|}}',
            text[max(0,m.start()-10):m.end()+10])
    
    # 1e. Nested red: {red| ... {red| ... } ... }
    for m in re.finditer(r'\{red\|[^}]*\{red\|', text):
        add('ERROR', fname, cid, 'NESTED_RED',
            f'{field}: nested {{red| inside {{red|',
            m.group()[:60])
    
    # 1f. Double opening parens before red: (({red|
    for m in re.finditer(r'\(\(\{red\|', text):
        add('ERROR', fname, cid, 'DOUBLE_OPEN_PAREN',
            f'{field}: (( before {{red|',
            text[m.start():m.start()+50])
    
    # ── 2. BOLD MARKER INTEGRITY ─────────────────────────────────────
    
    # 2a. Count ** markers — should be even
    # But we need to check per-paragraph since bold doesn't cross paragraphs
    paragraphs = text.split('\n')
    for pi, para in enumerate(paragraphs):
        # Skip empty paragraphs
        if not para.strip():
            continue
        
        # Strip {red|...} content first to avoid counting ** inside red tags
        stripped = re.sub(r'\{red\|[^}]*\}', 'REDTAG', para)
        star_count = stripped.count('**')
        if star_count % 2 != 0:
            add('ERROR', fname, cid, 'ODD_BOLD',
                f'{field}: paragraph has {star_count} ** markers (odd)',
                para.strip()[:100])
    
    # 2b. Empty bold: **** (truly empty, no newlines between)
    for m in re.finditer(r'\*\*\*\*', text):
        add('ERROR', fname, cid, 'EMPTY_BOLD',
            f'{field}: empty bold markers ****',
            text[max(0,m.start()-10):m.end()+10])
    
    # 2c. Bold glued to next word without space: **Word**NextWord (on same line)
    for m in re.finditer(r'\*\*([^*\n]{1,40})\*\*([A-Za-z])', text):
        inner = m.group(1)
        add('WARN', fname, cid, 'BOLD_GLUED',
            f'{field}: bold glued to next word',
            m.group()[:60])
    
    # ── 3. PARENTHESES / BRACKETS ────────────────────────────────────
    
    # 3a. Empty parentheses: ()
    for m in re.finditer(r'\(\s*\)', text):
        add('ERROR', fname, cid, 'EMPTY_PARENS',
            f'{field}: empty parentheses ()',
            text[max(0,m.start()-20):m.end()+20])
    
    # 3b. Orphan closing paren after {red|...}): should be ({red|...})
    # Actually check for unbalanced parens in scripture citation context
    
    # ── 4. QUOTE INTEGRITY ───────────────────────────────────────────
    
    # 4a. Count straight quotes — should be even
    double_quotes = text.count('"')
    if double_quotes % 2 != 0:
        # Find the orphan quote context
        positions = [m.start() for m in re.finditer('"', text)]
        if positions:
            last_pos = positions[-1]
            snippet = text[max(0, last_pos-30):last_pos+30]
            add('WARN', fname, cid, 'ODD_QUOTES',
                f'{field}: {double_quotes} double quotes (odd count)',
                snippet)
    
    # 4b. Curly/smart quotes mixed with straight quotes
    if re.search(r'[\u201c\u201d\u2018\u2019]', text):
        add('WARN', fname, cid, 'SMART_QUOTES',
            f'{field}: contains curly/smart quotes — should use straight quotes',
            '')
    
    # ── 5. BULLET INTEGRITY ──────────────────────────────────────────
    
    # 5a. Bullet with no content: "• " or "- " at end of line
    # Use ^ anchor to only match lines that START with a bullet marker
    for m in re.finditer(r'^\s*[•]\s*$', text, re.MULTILINE):
        add('ERROR', fname, cid, 'EMPTY_BULLET',
            f'{field}: bullet with no content',
            text[max(0,m.start()-10):m.end()+5])
    
    # 5b. Bullet marker stuck to text: "•Text" without space
    for m in re.finditer(r'•[A-Za-z]', text):
        add('ERROR', fname, cid, 'BULLET_NO_SPACE',
            f'{field}: bullet • without space after it',
            text[m.start():m.start()+30])
    
    # ── 6. WHITESPACE / FORMATTING ───────────────────────────────────
    
    # 6a. Leading/trailing whitespace in text value
    if text != text.strip():
        add('WARN', fname, cid, 'TEXT_WHITESPACE',
            f'{field}: has leading/trailing whitespace', '')
    
    # 6b. Triple+ newlines (excessive spacing)
    if '\n\n\n' in text:
        add('WARN', fname, cid, 'TRIPLE_NEWLINE',
            f'{field}: contains triple+ newlines', '')
    
    # 6c. Tab characters
    if '\t' in text:
        add('WARN', fname, cid, 'TAB_CHAR',
            f'{field}: contains tab characters', '')
    
    # 6d. Double spaces (outside of intentional contexts)
    if '  ' in text:
        add('WARN', fname, cid, 'DOUBLE_SPACE',
            f'{field}: contains double spaces', '')
    
    # ── 7. BROKEN NAME SPLITS ────────────────────────────────────────
    
    # "Dr.\n\nJohn" or "Mr.\n\nSmith" etc.
    if re.search(r'(?:Dr|Mr|Mrs|Ms|Rev|St)\.\s*\n', text):
        add('ERROR', fname, cid, 'BROKEN_NAME',
            f'{field}: honorific (Dr./Mr./etc.) split from name by newline',
            '')
    
    # ── 8. DUPLICATE PARAGRAPHS ──────────────────────────────────────
    
    non_empty = [p.strip() for p in text.split('\n') if p.strip() and len(p.strip()) > 30]
    para_counts = Counter(non_empty)
    for p, count in para_counts.items():
        if count > 1 and not re.match(r'^Name:\s*_+$', p):
            add('WARN', fname, cid, 'DUPLICATE_PARA',
                f'{field}: paragraph repeated {count}x',
                p[:80])
    
    # ── 9. SCRIPTURE REFERENCE ISSUES ────────────────────────────────
    
    # 9a. "{red|" appearing as literal visible text (unclosed in rendering context)
    # This catches multi-line {red| that would break the line-splitter
    for m in re.finditer(r'\{red\|([^}]*)\}', text, re.DOTALL):
        inner = m.group(1)
        if '\n' in inner:
            # Multi-line red tag — check if this would break line-by-line rendering
            # The RichTextParser handles this with dotAll, but flag if content is huge
            line_count = inner.count('\n') + 1
            if line_count > 20:
                add('WARN', fname, cid, 'HUGE_RED_SPAN',
                    f'{field}: {{red|}} spans {line_count} lines',
                    inner[:60])
    
    # ── 10. MISCELLANEOUS ────────────────────────────────────────────
    
    # 10a. HTML tags
    if re.search(r'<[a-z]+[^>]*>', text, re.IGNORECASE):
        add('WARN', fname, cid, 'HTML_TAG',
            f'{field}: contains HTML tags', '')
    
    # 10b. Markdown headers (#, ##, ###)
    if re.search(r'^#{1,3}\s', text, re.MULTILINE):
        add('WARN', fname, cid, 'MD_HEADER',
            f'{field}: contains Markdown headers', '')
    
    # 10c. Extremely long text without any paragraph breaks (wall of text)
    if len(text) > 2000 and '\n' not in text:
        add('WARN', fname, cid, 'WALL_OF_TEXT',
            f'{field}: {len(text)} chars with no line breaks', '')
    
    # 10d. Literal backslash-n in text (should be actual newline)
    if '\\n' in text and '\\n' not in repr(text).replace('\\n', ''):
        # This would only match if the JSON was incorrectly escaped
        pass  # JSON parser handles this correctly
    
    # 10e. Orphan closing brace } not part of {red|}
    # Count all } and subtract those that are part of {red|}
    total_close = text.count('}')
    red_close = len(re.findall(r'\{red\|[^}]*\}', text, re.DOTALL))
    if total_close > red_close:
        # Check if orphan braces are truly orphans
        stripped = re.sub(r'\{red\|[^}]*\}', '', text, flags=re.DOTALL)
        orphan_close = stripped.count('}')
        orphan_open = stripped.count('{')
        if orphan_close > 0 and orphan_open == 0:
            add('WARN', fname, cid, 'ORPHAN_BRACE',
                f'{field}: {orphan_close} orphan closing brace(s)',
                '')
        elif orphan_open > 0:
            add('ERROR', fname, cid, 'ORPHAN_OPEN_BRACE',
                f'{field}: {orphan_open} orphan opening brace(s)',
                stripped[stripped.index('{'):stripped.index('{')+30] if '{' in stripped else '')

# ─────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────

def main():
    base = "assets/config/journeys"
    folders = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]
    
    file_count = 0
    card_count = 0
    
    for folder in folders:
        path = os.path.join(base, folder)
        files = sorted(glob.glob(os.path.join(path, "*.json")))
        
        for filepath in files:
            fname = os.path.basename(filepath)
            file_count += 1
            
            # Validate JSON
            try:
                with open(filepath) as f:
                    data = json.load(f)
            except json.JSONDecodeError as e:
                add('ERROR', fname, 'file', 'INVALID_JSON', str(e))
                continue
            
            # Count cards
            for act in data.get('activities', []):
                card_count += len(act.get('cards', []))
            
            # Run structural + content checks
            check_json_structure(filepath, data, fname)
    
    # ── REPORT ────────────────────────────────────────────────────────
    
    errors = [i for i in issues if i[0] == 'ERROR']
    warns = [i for i in issues if i[0] == 'WARN']
    infos = [i for i in issues if i[0] == 'INFO']
    
    print(f"\n{'='*70}")
    print(f"  FINAL INDEPENDENT AUDIT — {file_count} files, {card_count} cards")
    print(f"{'='*70}")
    print(f"  ERRORS:   {len(errors)}")
    print(f"  WARNINGS: {len(warns)}")
    print(f"  INFO:     {len(infos)}")
    print(f"{'='*70}\n")
    
    if errors:
        print("❌  ERRORS (must fix)")
        print("─" * 70)
        current_file = ""
        for sev, fname, loc, code, msg, snippet in errors:
            if fname != current_file:
                current_file = fname
                print(f"\n  📄 {fname}")
            print(f"    [{code}] {msg}")
            if snippet:
                print(f"      → {snippet}")
        print()
    
    if warns:
        print("⚠️  WARNINGS (should review)")
        print("─" * 70)
        current_file = ""
        for sev, fname, loc, code, msg, snippet in warns:
            if fname != current_file:
                current_file = fname
                print(f"\n  📄 {fname}")
            print(f"    [{code}] {msg}")
            if snippet:
                print(f"      → {snippet}")
        print()
    
    if not errors and not warns:
        print("✅  ALL CLEAN — no errors or warnings found!\n")
    
    return 1 if errors else 0

if __name__ == '__main__':
    sys.exit(main())

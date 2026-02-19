#!/usr/bin/env python3
"""
World-Class Journey Content Auditor v3
======================================
Exhaustive quality check for all 65 journey JSON files.

Checks every card text field for:
  FORMATTING INTEGRITY - broken bold/italic/red markers
  VISUAL QUALITY - spacing, bullets, readability  
  CONTENT QUALITY - text flow, consistency, labeling

Understanding of the rendering pipeline:
  - _InfoCard: text split by \n+ => separate paragraph widgets (12px spacing)
    Each paragraph: _buildInlineSpans -> _processLines -> auto-bold Label: -> _buildEmphasisSpans
  - _ChoiceCard: prompt parsed by _parseRichContent which detects bullet lines (- * •)
  - Auto-bold Label: regex: ^([A-Za-z0-9\\s\\-\\(\\)]+):\\s*(.*)$
    ONLY matches if line starts with allowed chars — • or ** at start BREAKS it
  - Emphasis: {red|text}, **bold**, *italic*
"""

import json, os, re, sys, glob
from pathlib import Path
from collections import defaultdict

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

issues = []
stats = {"files": 0, "cards": 0, "text_fields": 0}


def add(filepath, card_id, sev, code, msg, ctx=""):
    """Add an issue to the report."""
    issues.append({
        "file": os.path.basename(filepath),
        "card": card_id,
        "sev": sev,
        "code": code,
        "msg": msg,
        "ctx": (ctx[:180] + "…" if len(ctx) > 180 else ctx) if ctx else ""
    })


# ════════════════════════════════════════════════════════════════════
# FORMATTING INTEGRITY CHECKS
# ════════════════════════════════════════════════════════════════════

def check_unpaired_bold(text, fp, cid):
    """Unpaired ** markers → literal ** visible to user."""
    # Remove valid **..** pairs (non-greedy, single-line)
    temp = text
    # Iteratively strip valid pairs
    while True:
        new = re.sub(r'\*\*(?!\s*\*\*).+?\*\*', '\x00', temp, flags=0)
        if new == temp:
            break
        temp = new
    if '**' in temp:
        idx = temp.index('**')
        # Get surrounding context from ORIGINAL text
        # Map back by finding the same region
        raw_context = text[max(0, idx-50):idx+80]
        add(fp, cid, "ERROR", "UNPAIRED_BOLD",
            "Unpaired ** bold marker — will show raw ** to user", raw_context)


def check_malformed_red(text, fp, cid):
    """All {red|...} formatting issues."""
    # Wrong syntax: {|red...}, {Red|...}, {RED|...}
    m = re.search(r'\{\s*\|[^}]*red', text, re.IGNORECASE)
    if m:
        add(fp, cid, "ERROR", "RED_WRONG_ORDER",
            "{|red instead of {red|", text[m.start():m.start()+30])
    
    # Wrong case: {Red|, {RED|
    for m in re.finditer(r'\{([A-Za-z]+)\|', text):
        tag = m.group(1)
        if tag.lower() == 'red' and tag != 'red':
            add(fp, cid, "ERROR", "RED_WRONG_CASE",
                f"{{{tag}| should be {{red|", m.group())
    
    # Empty {red|} or {red| }
    if re.search(r'\{red\|\s*\}', text):
        add(fp, cid, "ERROR", "RED_EMPTY",
            "Empty {red|} — renders nothing")
    
    # Unclosed {red| (no matching })
    opens = [(m.start(), m.end()) for m in re.finditer(r'\{red\|', text)]
    valid_pairs = [(m.start(), m.end()) for m in re.finditer(r'\{red\|[^}]*\}', text)]
    for o_start, o_end in opens:
        if not any(vs == o_start for vs, ve in valid_pairs):
            ctx = text[o_start:min(o_start+50, len(text))]
            add(fp, cid, "ERROR", "RED_UNCLOSED",
                "Unclosed {red| — raw syntax visible to user", ctx)
    
    # Orphan } that might be from a broken {red|}
    for m in re.finditer(r'\}', text):
        if not any(ve - 1 == m.start() for vs, ve in valid_pairs):
            # Only flag if there's a { nearby before it (likely broken pair)
            before = text[max(0, m.start()-60):m.start()]
            if '{' in before or 'red' in before.lower():
                ctx = text[max(0, m.start()-25):m.start()+5]
                add(fp, cid, "ERROR", "RED_ORPHAN_BRACE",
                    "Orphan } — likely from broken {red|}", ctx)
    
    # Stray {red| fragments: |red or red| outside of {red|}
    for m in re.finditer(r'(?<!\{)red\|(?!.*?\})', text):
        add(fp, cid, "ERROR", "RED_FRAGMENT",
            "Stray red| without opening {", text[m.start():m.start()+20])
    
    # Check for {| pattern (wrong order)
    for m in re.finditer(r'\{\|', text):
        add(fp, cid, "ERROR", "BRACE_PIPE",
            "Found {| — malformed formatting tag", text[m.start():m.start()+20])


def check_empty_bold(text, fp, cid):
    """Empty **** markers (not **\n\n** which is two separate bold spans)."""
    if '****' in text:
        add(fp, cid, "ERROR", "EMPTY_BOLD",
            "Empty bold markers **** — no content between **")
    # Only flag ** ** on the SAME LINE (not across paragraph breaks)
    for line in text.split('\n'):
        if re.search(r'\*\*\s+\*\*', line):
            add(fp, cid, "ERROR", "EMPTY_BOLD_WS",
                "Bold with only whitespace on same line: ** **", line.strip()[:40])


def check_bold_across_para(text, fp, cid):
    """Bold ** that spans across paragraph break (\n\n)."""
    paras = text.split('\n\n')
    for i, para in enumerate(paras):
        count = len(re.findall(r'\*\*', para))
        if count % 2 != 0:
            # This paragraph has an odd number of ** — bold spans the break
            ctx = para.strip()[:80]
            add(fp, cid, "ERROR", "BOLD_ACROSS_PARA",
                f"** spans paragraph break (section {i+1})", ctx)


# ════════════════════════════════════════════════════════════════════
# VISUAL QUALITY CHECKS  
# ════════════════════════════════════════════════════════════════════

def check_bold_glued(text, fp, cid):
    """Words glued to bold: **word**nextword or prevword**word**.
    Only flags when the bold span is short (<60 chars) to avoid false
    positives from matching across two independent bold spans."""
    # After closing **: **....**X where X is alpha
    for m in re.finditer(r'\*\*[^*\n]+?\*\*([a-zA-Z])', text):
        inner = m.group()[2:-3]  # text between ** markers
        # Skip if inner text is long (likely matching across two bold spans)
        if len(inner) > 60 or '. ' in inner:
            continue
        ctx = m.group()[:60]
        add(fp, cid, "ERROR", "BOLD_GLUED_AFTER",
            "Word glued after closing ** — missing space", ctx)
    
    # Before opening **: X**...** where X is alpha
    for m in re.finditer(r'([a-zA-Z])\*\*[^*\n]+?\*\*', text):
        inner = m.group()[3:-2]  # text between ** markers
        if len(inner) > 60 or '. ' in inner:
            continue
        pos = m.start()
        if pos > 0 and text[pos-1] not in (' ', '\n', '•', '-', '(', '"', "'"):
            ctx = text[max(0,pos-5):m.end()][:60]
            add(fp, cid, "ERROR", "BOLD_GLUED_BEFORE",
                "Word glued before opening ** — missing space", ctx)


def check_no_space_after_label(text, fp, cid):
    """**Label:**text with no space after colon."""
    for m in re.finditer(r'\*\*[^*\n]+?:\*\*(\S)', text):
        # Check it's not just punctuation
        next_char = m.group(1)
        if next_char.isalpha():
            ctx = m.group()[:50]
            add(fp, cid, "ERROR", "NO_SPACE_AFTER_LABEL",
                "No space after **Label:** — text runs together", ctx)


def check_bullet_spacing(text, fp, cid):
    """• not followed by space."""
    for m in re.finditer(r'•(\S)', text):
        ctx = text[m.start():m.start()+20]
        add(fp, cid, "ERROR", "BULLET_NO_SPACE",
            "Missing space after •", ctx)


def check_empty_bullets(text, fp, cid):
    """Bullet line with no content after marker."""
    for line in text.split('\n'):
        s = line.strip()
        if s in ('•', '• ', '-', '- ', '*'):
            add(fp, cid, "ERROR", "EMPTY_BULLET",
                "Empty bullet line — no content after marker", repr(s))


def check_inline_bullets(text, fp, cid):
    """Multiple • on the same line — should be split to separate lines."""
    for line in text.split('\n'):
        count = line.count('•')
        if count >= 2:
            add(fp, cid, "ERROR", "INLINE_BULLETS",
                f"Multiple • on same line ({count}) — should be on separate lines",
                line.strip()[:120])


def check_inline_numbered(text, fp, cid):
    """Multiple numbered items on same line: 1. First 2. Second."""
    for line in text.split('\n'):
        nums = re.findall(r'(?:^|\s)(\d+)\.\s+\S', line)
        if len(nums) >= 2:
            ints = [int(n) for n in nums]
            for i in range(len(ints)-1):
                if ints[i+1] == ints[i] + 1:
                    add(fp, cid, "ERROR", "INLINE_NUMBERED",
                        "Numbered items on same line — should be on separate lines",
                        line.strip()[:120])
                    break


def check_double_spaces(text, fp, cid):
    """Double spaces in text."""
    for i, line in enumerate(text.split('\n')):
        s = line.strip()
        if '  ' in s:
            # Find position of double space
            pos = s.index('  ')
            ctx = s[max(0,pos-20):pos+30]
            add(fp, cid, "WARN", "DOUBLE_SPACE",
                f"Double space on line {i+1}", ctx)


def check_double_period(text, fp, cid):
    """Double period .. that is NOT an ellipsis ..."""
    for m in re.finditer(r'(?<!\.)\.\.(?!\.)', text):
        ctx = text[max(0,m.start()-15):m.start()+15]
        add(fp, cid, "WARN", "DOUBLE_PERIOD",
            "Double period (..) — likely typo", ctx)


def check_trailing_whitespace(text, fp, cid):
    """Trailing spaces on lines."""
    for i, line in enumerate(text.split('\n')):
        if line != line.rstrip():
            add(fp, cid, "WARN", "TRAILING_WS",
                f"Trailing whitespace on line {i+1}")


def check_wall_of_text(text, fp, cid):
    """Very long single line with no breaks."""
    for line in text.split('\n'):
        s = line.strip()
        if len(s) > 450:
            add(fp, cid, "WARN", "WALL_OF_TEXT",
                f"Very long line ({len(s)} chars) — hard to read",
                s[:100] + "…")


def check_excess_newlines(text, fp, cid):
    """More than 3 consecutive newlines."""
    for m in re.finditer(r'\n{4,}', text):
        add(fp, cid, "WARN", "EXCESS_NEWLINES",
            f"Too many consecutive newlines ({len(m.group())})")


def check_orphan_quotes(text, fp, cid):
    """Odd number of double quotes."""
    count = text.count('"')
    if count % 2 != 0:
        add(fp, cid, "WARN", "ORPHAN_QUOTES",
            f"Odd number of double quotes ({count}) — likely unclosed quote")


def check_bullet_label_no_bold(text, fp, cid):
    """Bullet lines with Label: that won't auto-bold because • breaks the regex."""
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('• '):
            rest = s[2:].strip()
            # Check for a plain Label: pattern (not already **bold**)
            m = re.match(r'^([A-Z][A-Za-z0-9\s\-\(\)]{1,40}):\s', rest)
            if m and not rest.startswith('**'):
                label = m.group(1).strip()
                # Skip very common sentence patterns that happen to have colon
                if label.lower() not in ('example', 'for example', 'note', 'remember', 'ask yourself'):
                    add(fp, cid, "WARN", "BULLET_LABEL_NO_BOLD",
                        f"'{label}:' after • won't auto-bold — needs **{label}:**",
                        s[:80])


def check_mixed_bullet_styles(text, fp, cid):
    """Different bullet styles (•, -) in same text."""
    styles = set()
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('• '):
            styles.add('•')
        elif re.match(r'^-\s+\S', s):
            styles.add('-')
    if len(styles) > 1:
        add(fp, cid, "WARN", "MIXED_BULLETS",
            f"Mixed bullet styles in same card: {styles}")


# ════════════════════════════════════════════════════════════════════
# CONTENT QUALITY CHECKS
# ════════════════════════════════════════════════════════════════════

def check_single_bullet(text, fp, cid):
    """Only 1 bullet in entire text — should be a sentence instead."""
    bullet_lines = [l for l in text.split('\n') if l.strip().startswith('• ')]
    if len(bullet_lines) == 1:
        add(fp, cid, "INFO", "SINGLE_BULLET",
            "Only 1 bullet item — consider making it a regular sentence",
            bullet_lines[0].strip()[:100])


def check_all_bullets_no_intro(text, fp, cid):
    """Text that's entirely bullets with no introductory sentence."""
    lines = [l for l in text.split('\n') if l.strip()]
    bullet_lines = [l for l in lines if l.strip().startswith('• ')]
    if len(lines) > 2 and len(bullet_lines) == len(lines):
        add(fp, cid, "INFO", "ALL_BULLETS",
            f"Text is entirely bullets ({len(bullet_lines)}) with no intro sentence")


def check_bold_in_title(text, fp, cid):
    """Bold markers in title — usually unnecessary."""
    if '**' in text:
        add(fp, cid, "INFO", "BOLD_IN_TITLE",
            "Bold markers in title", text[:60])


def check_red_in_title(text, fp, cid):
    """Red formatting in title — unusual."""
    if '{red|' in text:
        add(fp, cid, "INFO", "RED_IN_TITLE",
            "{red|} in title", text[:60])


def check_newline_in_title(text, fp, cid):
    """Newlines in title — would render weirdly."""
    if '\n' in text:
        add(fp, cid, "ERROR", "NEWLINE_IN_TITLE",
            "Title contains newline", text[:60])


def check_long_title(text, fp, cid):
    """Very long title."""
    if len(text) > 80:
        add(fp, cid, "WARN", "LONG_TITLE",
            f"Title is very long ({len(text)} chars)", text[:80])


def check_long_bullet_items(text, fp, cid):
    """Bullet items that are very long — might read better as paragraphs."""
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('• ') and len(s) > 180:
            add(fp, cid, "INFO", "LONG_BULLET",
                f"Very long bullet ({len(s)} chars) — consider as paragraph",
                s[:100] + "…")


def check_numbered_without_space(text, fp, cid):
    """Numbered items like 1.Text without space after period."""
    for m in re.finditer(r'(?:^|\n)\s*(\d+\.)([A-Za-z])', text):
        ctx = m.group()[:20]
        add(fp, cid, "ERROR", "NUMBERED_NO_SPACE",
            f"No space after {m.group(1)} in numbered item", ctx)


def check_sentence_glued(text, fp, cid):
    """Sentences running together: period followed immediately by uppercase without space.
    But exclude common patterns like abbreviations, URLs, numbers."""
    for m in re.finditer(r'([a-z])\.([A-Z])', text):
        # Skip if it looks like an abbreviation context
        before = text[max(0,m.start()-5):m.start()+1]
        if re.search(r'[A-Z]\.', before):  # Abbreviation like U.S.A.
            continue
        ctx = text[max(0, m.start()-10):m.end()+15]
        add(fp, cid, "WARN", "SENTENCES_GLUED",
            "Sentences may be glued — missing space after period", ctx)


def check_missing_bold_close_at_colon(text, fp, cid):
    """Pattern like **Label: text (bold opened but colon is outside **)
    Should be **Label:** text instead."""
    for m in re.finditer(r'\*\*([^*\n:]+)\*\*:\s', text):
        label = m.group(1).strip()
        if len(label) < 40:
            add(fp, cid, "WARN", "BOLD_COLON_OUTSIDE",
                f"**{label}**: — colon outside bold, should be **{label}:**",
                m.group()[:50])


def check_leading_whitespace(text, fp, cid):
    """Lines with leading whitespace (not bullets)."""
    for i, line in enumerate(text.split('\n')):
        if line and line[0] == ' ' and line.strip():
            if not re.match(r'^\s+[•\-*\d]', line):
                add(fp, cid, "INFO", "LEADING_WS",
                    f"Leading whitespace on line {i+1}", repr(line[:40]))


def check_smart_quotes_mixed(text, fp, cid):
    """Mix of straight and curly quotes — should be consistent."""
    has_straight = '"' in text
    has_curly = '\u201c' in text or '\u201d' in text
    if has_straight and has_curly:
        add(fp, cid, "INFO", "MIXED_QUOTES",
            "Mix of straight and curly quotes")


def check_bullet_in_prompts(prompts, fp, cid):
    """Bullet characters in choice prompts — shouldn't be there."""
    for i, p in enumerate(prompts):
        if '•' in p:
            add(fp, cid, "WARN", "BULLET_IN_PROMPT",
                f"Bullet • in prompt option [{i}]", p[:60])


# ════════════════════════════════════════════════════════════════════
# MAIN TEXT AUDIT RUNNER
# ════════════════════════════════════════════════════════════════════

def audit_text(text, fp, cid):
    """Run all text checks."""
    if not text or not isinstance(text, str) or not text.strip():
        return
    
    stats["text_fields"] += 1
    
    # Formatting integrity
    check_unpaired_bold(text, fp, cid)
    check_malformed_red(text, fp, cid)
    check_empty_bold(text, fp, cid)
    check_bold_across_para(text, fp, cid)
    
    # Visual quality
    check_bold_glued(text, fp, cid)
    check_no_space_after_label(text, fp, cid)
    check_bullet_spacing(text, fp, cid)
    check_empty_bullets(text, fp, cid)
    check_inline_bullets(text, fp, cid)
    check_inline_numbered(text, fp, cid)
    check_double_spaces(text, fp, cid)
    check_double_period(text, fp, cid)
    check_trailing_whitespace(text, fp, cid)
    check_wall_of_text(text, fp, cid)
    check_excess_newlines(text, fp, cid)
    check_orphan_quotes(text, fp, cid)
    check_bullet_label_no_bold(text, fp, cid)
    check_mixed_bullet_styles(text, fp, cid)
    check_numbered_without_space(text, fp, cid)
    check_sentence_glued(text, fp, cid)
    check_missing_bold_close_at_colon(text, fp, cid)
    check_leading_whitespace(text, fp, cid)
    check_smart_quotes_mixed(text, fp, cid)
    
    # Content quality
    check_single_bullet(text, fp, cid)
    check_all_bullets_no_intro(text, fp, cid)
    check_long_bullet_items(text, fp, cid)


def audit_title(text, fp, cid):
    """Run title-specific checks."""
    if not text or not isinstance(text, str):
        return
    check_bold_in_title(text, fp, cid)
    check_red_in_title(text, fp, cid)
    check_newline_in_title(text, fp, cid)
    check_long_title(text, fp, cid)
    # Also run basic formatting checks on titles
    check_unpaired_bold(text, fp, cid)
    check_malformed_red(text, fp, cid)
    check_trailing_whitespace(text, fp, cid)
    check_double_spaces(text, fp, cid)


# ════════════════════════════════════════════════════════════════════
# FILE PROCESSING
# ════════════════════════════════════════════════════════════════════

def process_file(filepath):
    """Process a single journey JSON file."""
    stats["files"] += 1
    fname = os.path.basename(filepath)
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        add(filepath, "FILE", "ERROR", "JSON_INVALID", f"Invalid JSON: {e}")
        return
    
    # Process all activities
    activities = data.get("activities", [])
    for act in activities:
        act_id = act.get("id", act.get("activityNumber", "?"))
        cards = act.get("cards", [])
        
        for card in cards:
            stats["cards"] += 1
            card_id = card.get("cardId", card.get("id", "?"))
            card_type = card.get("cardType", "?")
            cid_base = f"{card_id}"
            
            # Audit title
            title = card.get("title", "")
            if title:
                audit_title(title, filepath, f"{cid_base}/title")
            
            # Audit main text field
            text = card.get("text", "")
            if text:
                audit_text(text, filepath, f"{cid_base}/text")
            
            # Audit reflection field (widowed journeys)
            reflection = card.get("reflection", "")
            if reflection and isinstance(reflection, str):
                audit_text(reflection, filepath, f"{cid_base}/reflection")
            
            # Audit prompts (question cards)
            prompts = card.get("prompts", [])
            if prompts and isinstance(prompts, list):
                check_bullet_in_prompts(prompts, filepath, cid_base)
                for i, p in enumerate(prompts):
                    if isinstance(p, str):
                        # Light checks on prompt options
                        check_unpaired_bold(p, filepath, f"{cid_base}/prompts[{i}]")
                        check_malformed_red(p, filepath, f"{cid_base}/prompts[{i}]")
                        check_double_spaces(p, filepath, f"{cid_base}/prompts[{i}]")
                        check_trailing_whitespace(p, filepath, f"{cid_base}/prompts[{i}]")


# ════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════

print("=" * 72)
print("WORLD-CLASS JOURNEY CONTENT AUDIT v3")
print("Checking every card in every file for visual perfection")
print("=" * 72)

for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        print(f"\n⚠ Folder missing: {folder_path}")
        continue
    
    files = sorted(folder_path.glob("*.json"))
    print(f"\n📁 {folder}/ ({len(files)} files)")
    
    for filepath in files:
        fname = filepath.name
        before_count = len(issues)
        process_file(str(filepath))
        after_count = len(issues)
        file_issues = after_count - before_count
        
        if file_issues == 0:
            print(f"  ✅ {fname}")
        else:
            file_errs = len([i for i in issues[before_count:] if i["sev"] == "ERROR"])
            file_warns = len([i for i in issues[before_count:] if i["sev"] == "WARN"])
            file_infos = len([i for i in issues[before_count:] if i["sev"] == "INFO"])
            parts = []
            if file_errs: parts.append(f"{file_errs}E")
            if file_warns: parts.append(f"{file_warns}W")
            if file_infos: parts.append(f"{file_infos}I")
            marker = "❌" if file_errs else "⚠️" if file_warns else "ℹ️"
            print(f"  {marker} {fname} [{', '.join(parts)}]")

# ════════════════════════════════════════════════════════════════════
# DETAILED REPORT
# ════════════════════════════════════════════════════════════════════

errors = [i for i in issues if i["sev"] == "ERROR"]
warns = [i for i in issues if i["sev"] == "WARN"]
infos = [i for i in issues if i["sev"] == "INFO"]

print(f"\n{'=' * 72}")
print(f"RESULTS: {stats['files']} files | {stats['cards']} cards | {stats['text_fields']} text fields checked")
print(f"  ERRORS:   {len(errors)}")
print(f"  WARNINGS: {len(warns)}")
print(f"  INFO:     {len(infos)}")
print(f"{'=' * 72}")

# Print all ERRORS grouped by file
if errors:
    print(f"\n{'─' * 72}")
    print("❌ ERRORS (must fix — broken rendering or visual glitches)")
    print(f"{'─' * 72}")
    by_file = defaultdict(list)
    for i in errors:
        by_file[i["file"]].append(i)
    for fname in sorted(by_file.keys()):
        print(f"\n  📄 {fname}")
        for i in by_file[fname]:
            print(f"    [{i['code']}] {i['card']}: {i['msg']}")
            if i["ctx"]:
                print(f"      → {i['ctx']}")

# Print all WARNINGS grouped by file
if warns:
    print(f"\n{'─' * 72}")
    print("⚠️  WARNINGS (likely issues — review needed)")
    print(f"{'─' * 72}")
    by_file = defaultdict(list)
    for i in warns:
        by_file[i["file"]].append(i)
    for fname in sorted(by_file.keys()):
        print(f"\n  📄 {fname}")
        for i in by_file[fname]:
            print(f"    [{i['code']}] {i['card']}: {i['msg']}")
            if i["ctx"]:
                print(f"      → {i['ctx']}")

# Print INFO grouped by code (summary only)
if infos:
    print(f"\n{'─' * 72}")
    print("ℹ️  INFO (awareness only)")
    print(f"{'─' * 72}")
    by_code = defaultdict(list)
    for i in infos:
        by_code[i["code"]].append(i)
    for code in sorted(by_code.keys()):
        items = by_code[code]
        print(f"\n  {code} ({len(items)} occurrences)")
        # Show first 3 examples
        for item in items[:3]:
            print(f"    {item['file']} {item['card']}: {item['msg']}")
            if item["ctx"]:
                print(f"      → {item['ctx']}")
        if len(items) > 3:
            print(f"    ... and {len(items)-3} more")

# Issue code summary
print(f"\n{'─' * 72}")
print("ISSUE CODE SUMMARY")
print(f"{'─' * 72}")
code_counts = defaultdict(int)
for i in issues:
    code_counts[f"{i['sev']:5s} {i['code']}"] += 1
for code, count in sorted(code_counts.items(), key=lambda x: (-x[1])):
    print(f"  {code}: {count}")

if not issues:
    print("\n🎉 ALL 65 FILES ARE PERFECTLY CLEAN — ZERO ISSUES FOUND!")
elif not errors and not warns:
    print(f"\n✅ No errors or warnings — only {len(infos)} informational notes.")

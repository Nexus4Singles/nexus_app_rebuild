#!/usr/bin/env python3
"""
Final accurate audit: eliminates false positives from thorough_audit.py.
Only detects REAL issues.
"""
import json, re
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"
MAP_FILE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journey_id_filename_map.json"
FOLDERS = [
    ("singles", BASE / "singles journeys"),
    ("married", BASE / "married journeys"),
    ("divorced", BASE / "divorced journeys"),
    ("widowed", BASE / "widowed journeys"),
]
with open(MAP_FILE) as f: FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())


def strip_markup(text):
    """Remove bold/red markers for content analysis."""
    t = re.sub(r'\*\*', '', text)
    t = re.sub(r'\{red\|([^}]*)\}', r'\1', t)
    return t


def audit_text(text, field):
    """Return list of (severity, category, description) for real issues only."""
    issues = []
    if not text or not text.strip():
        return issues
    
    lines = text.split('\n')
    
    # 1. UNPAIRED BOLD: lines with odd number of ** markers
    for i, line in enumerate(lines):
        count = line.count('**')
        if count % 2 != 0:
            issues.append(("ERROR", "UNPAIRED_BOLD",
                f"Line {i+1}: odd ** count ({count})", line.strip()[:90]))
    
    # 2. MALFORMED RED TAGS
    # Unclosed: {red| without }
    opens = text.count('{red|')
    closes = len(re.findall(r'\}', text))
    # Actually check for specifically unclosed red tags
    for m in re.finditer(r'\{red\|', text):
        # Find next } after this position
        pos = text.find('}', m.end())
        if pos == -1:
            ctx = text[m.start():min(m.start()+60, len(text))]
            issues.append(("ERROR", "UNCLOSED_RED",
                "Red tag opened but never closed", ctx.replace('\n','\\n')))
    
    # Nested red: {red|..{red|..}..}
    for m in re.finditer(r'\{red\|[^}]*\{red\|', text):
        issues.append(("ERROR", "NESTED_RED",
            "Nested red tags", m.group()[:80]))
    
    # 3. REAL INLINE BULLETS: actual • character repeated on same line
    # Exclude bold markers (**) from bullet detection
    for i, line in enumerate(lines):
        clean = strip_markup(line)
        # Count actual bullet characters (• not from bold markers)
        bullet_count = clean.count('• ')
        if bullet_count >= 2 and len(clean) > 50:
            issues.append(("WARNING", "INLINE_BULLETS",
                f"Line {i+1}: {bullet_count} bullet points on same line", clean.strip()[:90]))
    
    # 4. REAL INLINE NUMBERED LIST: 3+ numbered items on same line
    for i, line in enumerate(lines):
        clean = strip_markup(line)
        # Match actual numbered list patterns like "1. item 2. item 3. item"
        nums = re.findall(r'(?:^|\s)(\d+)\.\s', clean)
        if len(nums) >= 3 and len(clean) > 60:
            # Check they're sequential (real list)
            try:
                num_vals = [int(n) for n in nums]
                if num_vals == sorted(num_vals):
                    issues.append(("WARNING", "INLINE_NUMBERED_LIST",
                        f"Line {i+1}: {len(nums)} numbered items inline",
                        clean.strip()[:90]))
            except:
                pass
    
    # 5. WALL OF TEXT: paragraph > 500 chars without any line breaks
    paragraphs = re.split(r'\n\n+', text)
    for p in paragraphs:
        clean = strip_markup(p).strip()
        if len(clean) > 500 and '\n' not in p.strip():
            issues.append(("WARNING", "WALL_OF_TEXT",
                f"Paragraph of {len(clean)} chars without breaks",
                clean[:80] + "..."))
    
    # 6. WORDS TOGETHER: word.Word (missing space after period)
    for m in re.finditer(r'[a-z]\.[A-Z]', strip_markup(text)):
        ctx = strip_markup(text)[max(0,m.start()-15):m.end()+15]
        issues.append(("ERROR", "WORDS_TOGETHER",
            "Missing space after period", ctx))
    
    # 7. DOUBLE PERIOD: .. that isn't an ellipsis
    for m in re.finditer(r'\.\.(?!\.)', text):
        if m.start() > 0 and text[m.start()-1:m.start()] != '.':
            ctx = text[max(0,m.start()-15):m.end()+15].replace('\n','\\n')
            issues.append(("WARNING", "DOUBLE_PERIOD",
                "Double period found", ctx))
    
    # 8. TRAILING WHITESPACE
    for i, line in enumerate(lines):
        if line != line.rstrip():
            issues.append(("INFO", "TRAILING_WHITESPACE",
                f"Line {i+1} has trailing whitespace", ""))
            break  # Report once per text field
    
    # 9. ORPHAN QUOTES: lone " on its own line
    for i, line in enumerate(lines):
        if line.strip() == '"' or line.strip() == "'":
            issues.append(("ERROR", "ORPHAN_QUOTE",
                f"Line {i+1}: lone quote character on its own line", ""))
    
    # 10. BOLD ACROSS LINES: ** that spans multiple lines (parser may not handle this)
    # Find ** pairs and check if they cross \n
    for m in re.finditer(r'\*\*(.+?)\*\*', text, re.DOTALL):
        inner = m.group(1)
        if '\n' in inner and len(inner) > 200:
            issues.append(("WARNING", "BOLD_ACROSS_LINES",
                f"Bold spans {inner.count(chr(10))+1} lines ({len(inner)} chars)",
                inner[:60].replace('\n','\\n') + "..."))
    
    # 11. EXCESS NEWLINES: more than 2 consecutive newlines
    if '\n\n\n' in text:
        issues.append(("INFO", "EXCESS_NEWLINES", "Triple+ newlines found", ""))
    
    return issues


def main():
    files = []
    for cat, folder in FOLDERS:
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES:
                files.append((fp, fp.name, cat))
    
    print(f"Auditing {len(files)} files...\n")
    
    totals = {"ERROR": 0, "WARNING": 0, "INFO": 0}
    category_counts = {}
    files_with_issues = 0
    all_issues = []
    
    for filepath, filename, cat in files:
        with open(filepath) as f: data = json.load(f)
        
        cards = []
        for act in data.get("activities", []): cards.extend(act.get("cards", []))
        for mis in data.get("missions", []): cards.extend(mis.get("cards", []))
        
        file_issues = []
        for card in cards:
            cid = card.get("cardId", card.get("id", ""))
            for field in ["text", "prompt", "reflection"]:
                text = card.get(field, "")
                if not text: continue
                for severity, category, desc, ctx in audit_text(text, field):
                    file_issues.append((cid, field, severity, category, desc, ctx))
        
        if file_issues:
            files_with_issues += 1
            print(f"📄 {filename}")
            for cid, field, severity, category, desc, ctx in file_issues:
                icon = {"ERROR": "❌", "WARNING": "⚠️", "INFO": "ℹ️"}[severity]
                totals[severity] += 1
                category_counts[category] = category_counts.get(category, 0) + 1
                ctx_display = f' | "{ctx}"' if ctx else ""
                print(f"  {icon} [{category}] {cid}/{field}: {desc}{ctx_display}")
            print()
    
    print("=" * 60)
    print(f"\n📊 FINAL AUDIT SUMMARY")
    print(f"   Files audited: {len(files)}")
    print(f"   Files with issues: {files_with_issues}")
    print(f"   Total ERRORS: {totals['ERROR']}")
    print(f"   Total WARNINGS: {totals['WARNING']}")
    print(f"   Total INFO: {totals['INFO']}")
    
    if category_counts:
        print(f"\n📋 ISSUES BY CATEGORY:")
        for cat, count in sorted(category_counts.items(), key=lambda x: -x[1]):
            print(f"   {cat}: {count}")
    else:
        print("\n✅ NO ISSUES FOUND - ALL 65 FILES ARE CLEAN!")

if __name__ == "__main__":
    main()

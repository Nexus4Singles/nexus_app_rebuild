#!/usr/bin/env python3
"""
Thorough final audit of all 65 journey files.
Checks every card's text field for rendering issues.
"""
import json, os, re, sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"
MAP_FILE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journey_id_filename_map.json"

FOLDERS = {
    "singles": BASE / "singles journeys",
    "married": BASE / "married journeys",
    "divorced": BASE / "divorced journeys",
    "widowed": BASE / "widowed journeys",
}

# Load the canonical 65 files
with open(MAP_FILE) as f:
    FILE_MAP = json.load(f)

ACTIVE_FILES = set(FILE_MAP.values())

def get_all_active_files():
    """Return list of (filepath, filename) for all 65 active journey files."""
    files = []
    for folder in FOLDERS.values():
        if not folder.exists():
            continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES:
                files.append((fp, fp.name))
    return files

def extract_cards(data):
    """Extract all cards from a journey file (handles both schemas)."""
    cards = []
    # Activities schema (singles/married/divorced)
    for act in data.get("activities", []):
        for card in act.get("cards", []):
            cards.append(card)
    # Missions schema (widowed)
    for mission in data.get("missions", []):
        for card in mission.get("cards", []):
            cards.append(card)
    return cards

def get_text_fields(card):
    """Get all text content fields from a card."""
    fields = []
    for key in ["text", "prompt", "reflection"]:
        if key in card and card[key]:
            fields.append((key, card[key]))
    # Also check bullets
    if "bullets" in card and card["bullets"]:
        for i, b in enumerate(card["bullets"]):
            fields.append((f"bullets[{i}]", b))
    # Check options
    if "options" in card and card["options"]:
        for i, o in enumerate(card["options"]):
            if isinstance(o, str):
                fields.append((f"options[{i}]", o))
            elif isinstance(o, dict) and "text" in o:
                fields.append((f"options[{i}].text", o["text"]))
    return fields

class Issue:
    def __init__(self, severity, category, message, context=""):
        self.severity = severity  # "ERROR", "WARNING", "INFO"
        self.category = category
        self.message = message
        self.context = context[:150]  # truncate for readability
    def __repr__(self):
        ctx = f' | "{self.context}"' if self.context else ""
        return f"  [{self.severity}] {self.category}: {self.message}{ctx}"

def audit_text(text, field_name):
    """Run all checks on a text field. Return list of Issues."""
    issues = []
    
    # === 1. BOLD MARKUP ISSUES ===
    
    # 1a. Odd ** count per line (unpaired bold)
    for i, line in enumerate(text.split("\n")):
        count = line.count("**")
        if count % 2 != 0:
            issues.append(Issue("ERROR", "UNPAIRED_BOLD", 
                f"Line {i+1} has {count} ** markers (odd)", line.strip()[:100]))
    
    # 1b. Empty bold markers: ** ** or ****
    if re.search(r'\*\*\s*\*\*', text):
        match = re.search(r'\*\*\s*\*\*', text)
        issues.append(Issue("ERROR", "EMPTY_BOLD",
            "Empty bold markers found", text[max(0,match.start()-20):match.end()+20]))
    
    # 1c. Very long bold spans (>100 chars)
    for m in re.finditer(r'\*\*(.*?)\*\*', text, re.DOTALL):
        inner = m.group(1)
        if len(inner) > 100:
            issues.append(Issue("WARNING", "LONG_BOLD",
                f"Bold span is {len(inner)} chars", inner[:80]))
    
    # 1d. Bold wrapping entire paragraph (line >60 chars that is all bold)
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("**") and stripped.endswith("**") and len(stripped) > 70:
            inner = stripped[2:-2]
            if "**" not in inner:  # entire line is one bold span
                issues.append(Issue("WARNING", "FULL_LINE_BOLD",
                    f"Entire line ({len(inner)} chars) is bold", inner[:80]))
    
    # === 2. RED MARKUP ISSUES ===
    
    # 2a. Unclosed {red| 
    opens = text.count("{red|")
    closes = text.count("}")
    # More precise: find {red| without matching }
    for m in re.finditer(r'\{red\|', text):
        # Find next } after this position
        rest = text[m.end():]
        if "}" not in rest:
            issues.append(Issue("ERROR", "UNCLOSED_RED",
                "Unclosed {red| tag", text[m.start():m.start()+60]))
    
    # 2b. Malformed red tags like {red|text|extra}
    for m in re.finditer(r'\{red\|([^}]*)\}', text):
        inner = m.group(1)
        if "|" in inner:
            issues.append(Issue("ERROR", "MALFORMED_RED",
                f"Red tag has extra pipe: {inner[:50]}", m.group(0)[:80]))
    
    # 2c. Bold wrapping red tags: **{red|...}** (redundant - red already is w600)
    for m in re.finditer(r'\*\*\{red\|[^}]*\}\*\*', text):
        issues.append(Issue("INFO", "BOLD_AROUND_RED",
            "Bold wrapping red tag (redundant)", m.group(0)[:80]))
    
    # 2d. Nested red inside red or red syntax errors
    for m in re.finditer(r'\{red\|[^}]*\{', text):
        issues.append(Issue("ERROR", "NESTED_RED",
            "Nested { inside red tag", m.group(0)[:80]))
    
    # 2e. Bare {red| with no content
    for m in re.finditer(r'\{red\|\s*\}', text):
        issues.append(Issue("ERROR", "EMPTY_RED",
            "Empty {red|} tag", ""))
    
    # === 3. TEXT FLOW / READABILITY ===
    
    # 3a. Wall of text: any paragraph > 500 chars without a \n break
    for i, para in enumerate(text.split("\n\n")):
        if len(para.strip()) > 500 and "\n" not in para.strip():
            issues.append(Issue("WARNING", "WALL_OF_TEXT",
                f"Paragraph {i+1} is {len(para.strip())} chars with no line break",
                para.strip()[:100]))
    
    # 3b. Multiple sentences jammed together without \n\n separation
    # (look for patterns like "sentence end.Next sentence" without space after period)
    for m in re.finditer(r'[a-z]\.[A-Z]', text):
        word_before = text[max(0,m.start()-10):m.start()+1]
        word_after = text[m.start()+1:m.start()+15]
        # Skip known abbreviations
        if not any(abbr in word_before for abbr in ['Dr.', 'Mr.', 'Mrs.', 'St.', 'vs.', 'e.g.', 'i.e.']):
            issues.append(Issue("ERROR", "WORDS_TOGETHER",
                "Period not followed by space", text[max(0,m.start()-15):m.start()+15]))
    
    # 3c. Orphaned quotation marks (lone " on its own line)
    for i, line in enumerate(text.split("\n")):
        if line.strip() == '"' or line.strip() == '"' or line.strip() == '"':
            issues.append(Issue("ERROR", "ORPHAN_QUOTE",
                    f"Lone quotation mark on line {i+1}", ""))
    
    # 3d. Double periods
    if ".." in text and "..." not in text.replace("....", ""):
        # Find actual .. that aren't part of ...
        for m in re.finditer(r'(?<!\.)\.\.(?!\.)', text):
            issues.append(Issue("ERROR", "DOUBLE_PERIOD",
                "Double period found", text[max(0,m.start()-15):m.end()+15]))
    
    # 3e. Triple+ newlines (excessive spacing)
    if "\n\n\n" in text:
        issues.append(Issue("WARNING", "EXCESS_NEWLINES",
            "Three or more consecutive newlines", ""))
    
    # 3f. Leading/trailing whitespace on lines
    has_trailing = False
    for line in text.split("\n"):
        if line != line.rstrip() and line.strip():
            has_trailing = True
            break
    if has_trailing:
        issues.append(Issue("INFO", "TRAILING_WHITESPACE",
            "Some lines have trailing whitespace", ""))
    
    # === 4. LIST FORMATTING ===
    
    # 4a. Inline bullets: "• item1 • item2" on same line
    for i, line in enumerate(text.split("\n")):
        bullet_count = len(re.findall(r'[•\-\*]\s', line))
        if bullet_count >= 2 and len(line) > 40:
            issues.append(Issue("WARNING", "INLINE_BULLETS",
                f"Line {i+1} has {bullet_count} bullets on same line", line[:100]))
    
    # 4b. Numbered list items on same line: "1. item 2. item 3. item"
    for i, line in enumerate(text.split("\n")):
        numbered = re.findall(r'\d+\.\s', line)
        if len(numbered) >= 3 and len(line) > 60:
            issues.append(Issue("WARNING", "INLINE_NUMBERED_LIST",
                f"Line {i+1} has {len(numbered)} numbered items on same line", line[:100]))
    
    # 4c. Label items packed together: "Label1: text Label2: text"
    # Look for multiple "Word:" patterns on same line without \n between them
    for i, line in enumerate(text.split("\n")):
        labels = re.findall(r'[A-Z][a-z]+(?:\s[A-Z][a-z]+)*:\s', line)
        if len(labels) >= 2 and len(line) > 80:
            issues.append(Issue("WARNING", "PACKED_LABELS",
                f"Line {i+1} has {len(labels)} label patterns on same line",
                line[:100]))
    
    # === 5. CONTENT QUALITY ===
    
    # 5a. Stray markup characters
    # Lone * that isn't part of ** or bullet
    for i, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if stripped == "*" or stripped == "**":
            issues.append(Issue("ERROR", "STRAY_MARKUP",
                f"Lone markup character on line {i+1}", stripped))
    
    # 5b. Unmatched parentheses/brackets in single line
    for i, line in enumerate(text.split("\n")):
        if line.count("(") != line.count(")") and len(line) > 5:
            # Filter out {red|} tags which use { }
            clean = re.sub(r'\{red\|[^}]*\}', '', line)
            if clean.count("(") != clean.count(")"):
                issues.append(Issue("INFO", "UNMATCHED_PARENS",
                    f"Unmatched parentheses on line {i+1}", line[:80]))
    
    # 5c. Scripture reference outside {red|} tags
    # Look for common patterns like "John 3:16" not wrapped in red
    scripture_pattern = r'(?<!\{red\|)(?<!\|)\b(Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|1\s*Samuel|2\s*Samuel|1\s*Kings|2\s*Kings|1\s*Chronicles|2\s*Chronicles|Ezra|Nehemiah|Esther|Job|Psalm|Psalms|Proverbs|Ecclesiastes|Song\s*of\s*Solomon|Isaiah|Jeremiah|Lamentations|Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|Matthew|Mark|Luke|John|Acts|Romans|1\s*Corinthians|2\s*Corinthians|Galatians|Ephesians|Philippians|Colossians|1\s*Thessalonians|2\s*Thessalonians|1\s*Timothy|2\s*Timothy|Titus|Philemon|Hebrews|James|1\s*Peter|2\s*Peter|1\s*John|2\s*John|3\s*John|Jude|Revelation)\s+\d+:\d+'
    for m in re.finditer(scripture_pattern, text):
        # Check if it's inside a {red|} tag
        # Look backwards for {red| without closing }
        before = text[:m.start()]
        last_red = before.rfind("{red|")
        last_close = before.rfind("}")
        if last_red == -1 or last_close > last_red:
            # Not inside a red tag
            issues.append(Issue("WARNING", "SCRIPTURE_NOT_RED",
                f"Scripture reference not in {{red|}}", m.group(0)[:60]))
    
    # 5d. Quote marks that start a line but content doesn't close the quote
    for i, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if stripped.startswith('"') and not stripped.endswith('"') and len(stripped) > 5:
            # Check if it's a multi-line quote (next lines close it)
            # This is just informational
            pass  # too many false positives
    
    # 5e. Broken bold closing - ** at start of line likely means bold from prev line leaked
    for i, line in enumerate(text.split("\n")):
        stripped = line.strip()
        if stripped.startswith("**") and not stripped.startswith("***") and i > 0:
            # Check if previous line has an opening **
            prev = text.split("\n")[i-1].strip()
            if prev.endswith("**"):
                issues.append(Issue("WARNING", "BOLD_ACROSS_LINES",
                    f"Bold marker at start of line {i+1}, prev line ends with **",
                    stripped[:60]))
    
    return issues


def audit_file(filepath):
    """Audit a single journey file. Returns dict of issues by card."""
    with open(filepath) as f:
        data = json.load(f)
    
    cards = extract_cards(data)
    file_issues = {}
    
    for card in cards:
        card_id = card.get("cardId") or card.get("id") or "unknown"
        card_title = card.get("title", "untitled")
        card_type = card.get("cardType") or card.get("type") or "unknown"
        
        fields = get_text_fields(card)
        card_issues = []
        
        for field_name, field_text in fields:
            issues = audit_text(field_text, field_name)
            for issue in issues:
                issue.message = f"[{field_name}] {issue.message}"
                card_issues.append(issue)
        
        if card_issues:
            file_issues[f"{card_id} ({card_title})"] = card_issues
    
    return file_issues


def main():
    files = get_all_active_files()
    print(f"Auditing {len(files)} active journey files...")
    print("=" * 80)
    
    total_errors = 0
    total_warnings = 0
    total_info = 0
    files_with_issues = 0
    
    # Collect all issues for summary
    all_category_counts = {}
    all_issues_detail = []
    
    for filepath, filename in files:
        file_issues = audit_file(filepath)
        
        if file_issues:
            files_with_issues += 1
            print(f"\n📁 {filename}")
            
            for card_key, issues in file_issues.items():
                print(f"\n  🃏 Card: {card_key}")
                for issue in issues:
                    print(f"    {issue}")
                    if issue.severity == "ERROR":
                        total_errors += 1
                    elif issue.severity == "WARNING":
                        total_warnings += 1
                    else:
                        total_info += 1
                    
                    cat = issue.category
                    all_category_counts[cat] = all_category_counts.get(cat, 0) + 1
                    all_issues_detail.append((filename, card_key, issue))
    
    print("\n" + "=" * 80)
    print(f"\n📊 SUMMARY")
    print(f"   Files audited: {len(files)}")
    print(f"   Files with issues: {files_with_issues}")
    print(f"   Total ERRORS: {total_errors}")
    print(f"   Total WARNINGS: {total_warnings}")
    print(f"   Total INFO: {total_info}")
    
    if all_category_counts:
        print(f"\n📋 ISSUES BY CATEGORY:")
        for cat, count in sorted(all_category_counts.items(), key=lambda x: -x[1]):
            print(f"   {cat}: {count}")
    
    print()
    return total_errors + total_warnings


if __name__ == "__main__":
    result = main()
    sys.exit(0 if result == 0 else 1)

#!/usr/bin/env python3
"""
Comprehensive formatting fix for all 65 journey files.
Multi-pass approach: structural markup → quotes → bold → text flow.
"""
import json, os, re, sys, copy
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"
MAP_FILE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journey_id_filename_map.json"

FOLDERS = {
    "singles": BASE / "singles journeys",
    "married": BASE / "married journeys",
    "divorced": BASE / "divorced journeys",
    "widowed": BASE / "widowed journeys",
}

with open(MAP_FILE) as f:
    FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())

BIBLE_BOOKS = (
    r'Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|'
    r'1\s*Samuel|2\s*Samuel|1\s*Kings|2\s*Kings|1\s*Chronicles|2\s*Chronicles|'
    r'Ezra|Nehemiah|Esther|Job|Psalms?|Proverbs|Ecclesiastes|'
    r'Song\s*of\s*Solomon|Songs?\s*of\s*Songs?|Isaiah|Jeremiah|Lamentations|'
    r'Ezekiel|Daniel|Hosea|Joel|Amos|Obadiah|Jonah|Micah|Nahum|Habakkuk|'
    r'Zephaniah|Haggai|Zechariah|Malachi|'
    r'Matthew|Mark|Luke|John|Acts|Romans|'
    r'1\s*Corinthians|2\s*Corinthians|Galatians|Ephesians|Philippians|'
    r'Colossians|1\s*Thessalonians|2\s*Thessalonians|'
    r'1\s*Timothy|2\s*Timothy|Titus|Philemon|Hebrews|James|'
    r'1\s*Peter|2\s*Peter|1\s*John|2\s*John|3\s*John|Jude|Revelation|'
    r'Solomon'
)

def get_all_active_files():
    files = []
    for folder in FOLDERS.values():
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES:
                files.append((fp, fp.name))
    return files

# ============================================================
# PASS 1: Structural markup fixes (red tags, parens, braces)
# ============================================================

def pass1_fix_markup(text):
    """Fix red tag markup issues."""
    original = text

    # 1a. Remove ** inside red tag references: {red|Book Ch:** V...} → {red|Book Ch:V...}
    text = re.sub(r'(\{red\|[^}]*?)\*\*\s*', lambda m: m.group(1), text)

    # 1b. Fix malformed two-pipe red tags: {red|Ref|Content} → {red|Ref}
    # Match {red|Reference|extra content that may span lines}
    def fix_two_pipe(m):
        ref = m.group(1).strip()
        # Clean the reference: remove extra spaces around colons
        ref = re.sub(r'\s*:\s*', ':', ref)
        return '{red|' + ref + '}'

    text = re.sub(r'\{red\|([^|}]+)\|[^}]*\}', fix_two_pipe, text, flags=re.DOTALL)

    # 1c. Fix bare scripture references not wrapped in {red|}
    # Pattern: "BibleBook Chapter:Verse|Content)." outside existing {red|}
    # First check we're not inside an existing {red|} tag
    def fix_bare_scripture(m):
        book = m.group(1).strip()
        chapter_verse = m.group(2).strip()
        # Clean spaces in reference
        ref = f"{book} {chapter_verse}"
        ref = re.sub(r'\s*:\s*', ':', ref)
        return '({red|' + ref + '})'

    # Match BibleBook Chapter:Verse|Content). NOT preceded by {red|
    bare_pattern = rf'(?<!\{{red\|)(?<!\|)\b({BIBLE_BOOKS})\s+(\d+\s*:\s*\d+(?:\s*-\s*\d+)?)\s*\|[^)]*\)'
    text = re.sub(bare_pattern, fix_bare_scripture, text)

    # 1d. Fix stray ")." or ") " after {red|...} closing brace
    # Pattern: }) → just } (remove the stray closing paren)
    # But preserve ({red|...}) which is valid (paren wrapping the tag)
    # Detect: text}). → text}).  If preceded by ({red|, the ) is closing the (
    # So we only remove ) when there's no matching ( before the {red|
    def fix_stray_paren(m):
        before = m.group(1)
        after = m.group(3)
        # Check if there's a matching ( before
        before_text = text[:m.start()]
        # Count unmatched ( before
        last_100 = before_text[-100:] if len(before_text) > 100 else before_text
        open_parens = last_100.count('(') - last_100.count(')')
        if open_parens > 0:
            # There IS an unmatched ( → the ) is legitimate
            return m.group(0)
        else:
            # No matching ( → remove the stray )
            return before + '}' + after

    text = re.sub(r'(\{red\|[^}]*)(}\)\s*)(\.?)', fix_stray_paren, text)

    # 1e. Remove completely stray }) patterns that resulted from broken markup
    # Pattern: just "). " or ")." when not after a valid ({red|...})
    text = re.sub(r'\n\)\.\s*', '\n', text)

    # 1f. Fix stray } in text that's not part of a {red|} tag
    # Find } that is NOT preceded by {red|...
    def remove_stray_brace(text):
        result = []
        i = 0
        while i < len(text):
            if text[i] == '{' and text[i:i+5] == '{red|':
                # Skip the entire {red|..} tag
                end = text.find('}', i+5)
                if end != -1:
                    result.append(text[i:end+1])
                    i = end + 1
                else:
                    result.append(text[i])
                    i += 1
            elif text[i] == '}':
                # Stray } - skip it
                i += 1
            else:
                result.append(text[i])
                i += 1
        return ''.join(result)

    text = remove_stray_brace(text)

    # 1g. Fix empty red tags: {red|} → remove
    text = re.sub(r'\{red\|\s*\}', '', text)

    # 1h. Clean references: extra spaces in chapter:verse
    text = re.sub(r'(\{red\|[^}]*?)\s+(\d)', lambda m: m.group(1) + ' ' + m.group(2), text)

    return text


# ============================================================
# PASS 2: Quote cleanup
# ============================================================

def pass2_fix_quotes(text):
    """Fix orphan quotation marks and broken quote patterns."""

    # 2a. Fix orphan opening quotes: lone " on its own line followed by text
    # Pattern: \n"\n → merge " with next line
    # Handle both regular " and smart quotes " "

    lines = text.split('\n')
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped in ('"', '\u201c', '\u201d'):  # lone quote marks
            if i + 1 < len(lines) and lines[i + 1].strip():
                # Merge with next line (opening quote)
                lines[i + 1] = stripped + lines[i + 1].lstrip()
                lines[i] = ''
            elif i > 0 and lines[i - 1].strip():
                # Merge with previous line (closing quote)
                lines[i - 1] = lines[i - 1].rstrip() + stripped
                lines[i] = ''
        i += 1

    text = '\n'.join(lines)

    # 2b. Fix opening quote followed by paragraph break:
    # Pattern: text "\n\nContent" → text\n\n"Content"
    # This moves the opening " to the start of the actual quote
    text = re.sub(r'(\s)"(\n\n)(\S)', r'\1\2"\3', text)

    # 2c. Fix "Solomon 8:7))" and similar broken references
    text = re.sub(r'Solomon\s+(\d+:\d+)\)\)', r'({red|Song of Solomon \1})', text)

    return text


# ============================================================
# PASS 3: Bold cleanup
# ============================================================

def pass3_fix_bold(text):
    """Fix unpaired bold markers and redundant bold."""

    # 3a. Remove bold from labels that the parser auto-bolds
    # Pattern: **Label: text → Label: text
    # The parser auto-bolds "Label:" at start of line
    # But ONLY if the bold wraps just the label or a short segment
    # Keep bold on short emphasis like **Step 1:** or **Note:**
    def clean_bold_labels(text):
        lines = text.split('\n')
        for i, line in enumerate(lines):
            stripped = line.strip()

            # Pattern: **Label: text (no closing ** on same line → unpaired)
            m = re.match(r'^\*\*([A-Za-z0-9\s\-\(\)]+:\s+.{20,})$', stripped)
            if m and '**' not in stripped[2:]:
                # Long content after label with opening ** but no closing
                # Remove the opening ** since auto-bold handles the label
                lines[i] = line.replace('**', '', 1)
                continue

            # Pattern: **Label: long text** (entire line bold, mainly label)
            m = re.match(r'^\*\*([A-Za-z0-9\s\-\(\)]+:\s+.{40,})\*\*$', stripped)
            if m:
                # Remove bold from entire long line
                lines[i] = stripped[2:-2]
                continue

        return '\n'.join(lines)

    text = clean_bold_labels(text)

    # 3b. Remove lone ** on its own line
    text = re.sub(r'\n\*\*\n', '\n\n', text)
    text = re.sub(r'^\*\*$', '', text, flags=re.MULTILINE)

    # 3c. Fix **". and .**" patterns (bold crossing quote boundaries)
    # Pattern: **"\n → "\n (remove bold around quotes)
    text = re.sub(r'\*\*"(\n)', r'"\1', text)
    text = re.sub(r'"\*\*(\n)', r'"\1', text)

    # 3d. Fix bold markers around periods: .**. → .**
    text = re.sub(r'\.\*\*\.', '.**', text)

    # 3e. Fix double bold: **** → (remove)
    text = re.sub(r'\*{4,}', '', text)

    # 3f. Check each line for unpaired bold and try to fix
    lines = text.split('\n')
    for i, line in enumerate(lines):
        count = line.count('**')
        if count % 2 != 0 and count > 0:
            stripped = line.strip()

            # If line ends with ** and it's a closing marker with no opening
            if stripped.endswith('**') and count == 1:
                lines[i] = line.rstrip().rstrip('*').rstrip()
                continue

            # If line starts with ** and it's an opening with no close
            if stripped.startswith('**') and count == 1:
                # Check if it's a label line → remove **
                if re.match(r'\*\*[A-Za-z]', stripped):
                    # Check if next significant content suggests it was meant as bold label
                    rest = stripped[2:]
                    # If it ends with punctuation, add closing **
                    if rest.endswith('.') or rest.endswith(':') or rest.endswith('!'):
                        lines[i] = '**' + rest + '**' if len(rest) < 80 else rest
                    else:
                        lines[i] = rest  # Just remove the orphan opening
                continue

            # 3 ** markers: likely one bold pair + one orphan
            if count == 3:
                # Find the orphan: try pairing first two, check if third is at end
                if stripped.endswith('**'):
                    # Remove trailing orphan **
                    lines[i] = line.rstrip()[:-2]

    text = '\n'.join(lines)

    # 3g. Remove empty bold: ** ** or ** \n** etc.
    text = re.sub(r'\*\*\s*\*\*', '', text)

    return text


# ============================================================
# PASS 4: Text flow fixes
# ============================================================

def pass4_fix_text_flow(text):
    """Fix text flow issues: spacing, periods, newlines."""

    # 4a. Fix words running together: word.Word → word. Word
    # But skip abbreviations like Dr., Mr., etc.
    abbrevs = {'Dr', 'Mr', 'Mrs', 'Ms', 'St', 'vs', 'Jr', 'Sr', 'Fr', 'etc', 'Vol'}
    def fix_word_together(m):
        before = m.group(1)
        after = m.group(2)
        # Check for abbreviation
        word_before = re.search(r'(\w+)$', text[:m.start()+1])
        if word_before and word_before.group(1) in abbrevs:
            return m.group(0)
        return before + '. ' + after

    text = re.sub(r'([a-z])\.([A-Z])', fix_word_together, text)

    # Also fix patterns like: word.**Word or word."Word
    text = re.sub(r'(\w)\.\*\*([A-Z])', r'\1.\n\n**\2', text)

    # 4b. Fix double periods (not part of ellipsis)
    text = re.sub(r'(?<!\.)\.\.(?!\.)', '.', text)

    # 4c. Fix triple+ newlines → double
    text = re.sub(r'\n{3,}', '\n\n', text)

    # 4d. Strip trailing whitespace from lines
    lines = text.split('\n')
    lines = [line.rstrip() for line in lines]
    text = '\n'.join(lines)

    # 4e. Strip leading/trailing whitespace from entire text
    text = text.strip()

    return text


# ============================================================
# PASS 5: Final cleanup
# ============================================================

def pass5_final_cleanup(text):
    """Final pass for remaining edge cases."""

    # 5a. Remove any remaining empty bold pairs
    text = re.sub(r'\*\*\s*\*\*', '', text)

    # 5b. Clean up stray ), and ). patterns
    text = re.sub(r'\n\)\.\s*', '\n', text)
    text = re.sub(r'\n\)\s*\n', '\n\n', text)

    # 5c. Fix stray , after red tags: {red|Ref}, 4) → {red|Ref})
    text = re.sub(r'(\{red\|[^}]+\}),\s*\d+\)', r'\1)', text)

    # 5d. Another pass on triple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)

    # 5e. Fix patterns like "({red|...})." → "({red|...})."  (already fine)
    # But fix "({red|...}). " with extra space → "({red|...}). "

    # 5f. Remove orphan ) at start of text
    text = re.sub(r'^[\s\)\.]+(?=\S)', '', text)

    # 5g. Fix any remaining double periods
    text = re.sub(r'(?<!\.)\.\.(?!\.)', '.', text)

    return text.strip()


# ============================================================
# Main processing
# ============================================================

def process_text(text):
    """Apply all fix passes to a text field."""
    if not text or not text.strip():
        return text
    t = text
    t = pass1_fix_markup(t)
    t = pass2_fix_quotes(t)
    t = pass3_fix_bold(t)
    t = pass4_fix_text_flow(t)
    t = pass5_final_cleanup(t)
    return t

def process_file(filepath):
    """Process a single journey file. Returns (modified, data) tuple."""
    with open(filepath) as f:
        data = json.load(f)

    modified = False
    text_fields = ["text", "prompt", "reflection"]

    def process_cards(cards):
        nonlocal modified
        for card in cards:
            for field in text_fields:
                if field in card and card[field] and isinstance(card[field], str):
                    original = card[field]
                    fixed = process_text(original)
                    if fixed != original:
                        card[field] = fixed
                        modified = True

            # Process bullets
            if "bullets" in card and card["bullets"]:
                for i, b in enumerate(card["bullets"]):
                    if isinstance(b, str):
                        fixed = process_text(b)
                        if fixed != b:
                            card["bullets"][i] = fixed
                            modified = True

            # Process options
            if "options" in card and card["options"]:
                for i, o in enumerate(card["options"]):
                    if isinstance(o, str):
                        fixed = process_text(o)
                        if fixed != o:
                            card["options"][i] = fixed
                            modified = True

    # Process activities schema
    for act in data.get("activities", []):
        process_cards(act.get("cards", []))

    # Process missions schema (widowed)
    for mission in data.get("missions", []):
        process_cards(mission.get("cards", []))

    return modified, data


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} active journey files...\n")

    modified_count = 0
    for filepath, filename in files:
        modified, data = process_file(filepath)
        if modified:
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write('\n')
            modified_count += 1
            print(f"  ✓ Modified: {filename}")
        else:
            print(f"  · Unchanged: {filename}")

    print(f"\nDone. Modified {modified_count}/{len(files)} files.")

    # Validate JSON
    errors = 0
    for filepath, filename in files:
        try:
            with open(filepath) as f:
                json.load(f)
        except json.JSONDecodeError as e:
            print(f"  ✗ JSON ERROR in {filename}: {e}")
            errors += 1

    print(f"JSON validation: {errors} errors")
    return modified_count


if __name__ == "__main__":
    main()

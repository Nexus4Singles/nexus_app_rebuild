#!/usr/bin/env python3
"""
World-Class Content Fixer v3
============================
Fixes ALL issues found by worldclass_audit.py:

Pass 1: Remove empty bullet lines (•)
Pass 2: Fix bullet labels without bold (• Label: → • **Label:**)
Pass 3: Fix missing space after • 
Pass 4: Normalize dash bullets to •
Pass 5: Fix bold colon outside (**Label**: → **Label:**)
Pass 6: Fix broken bold structures (missing opening **, extra **, merged lines)
Pass 7: Fix EMPTY_BOLD_WS false positives — actually **\n\n** is fine, but **\n** by itself is odd
Pass 8: Split wall-of-text summary cards
Pass 9: Fix inline numbered lists
"""

import json, os, re, glob, copy
from pathlib import Path

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

total_fixes = 0
files_modified = 0
fix_log = []

def log(filepath, card_id, fix_type, detail):
    global total_fixes
    total_fixes += 1
    fix_log.append({
        "file": os.path.basename(filepath),
        "card": card_id,
        "type": fix_type,
        "detail": detail[:120]
    })

# ════════════════════════════════════════════════════════════════════
# PASS 1: Remove empty bullet lines
# ════════════════════════════════════════════════════════════════════

def fix_empty_bullets(text, fp, cid):
    """Remove lines that are just '•' with nothing after."""
    lines = text.split('\n')
    new_lines = []
    changed = False
    for line in lines:
        if line.strip() == '•' or line.strip() == '• ':
            log(fp, cid, "REMOVE_EMPTY_BULLET", "Removed empty • line")
            changed = True
            continue
        new_lines.append(line)
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 2: Fix bullet labels without bold
# ════════════════════════════════════════════════════════════════════

def fix_bullet_label_no_bold(text, fp, cid):
    """Add **bold** to labels after • that won't auto-bold."""
    lines = text.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        s = line.strip()
        if s.startswith('• '):
            rest = s[2:].strip()
            # Match Label: pattern (capitalized, reasonable length)
            m = re.match(r'^([A-Z][A-Za-z0-9\s\-\(\)\']{1,50}):\s', rest)
            if m and not rest.startswith('**'):
                label = m.group(1).strip()
                # Skip common sentence patterns that have colons
                skip_labels = {'example', 'for example', 'note', 'remember', 'ask yourself',
                              'in other words', 'the point', 'the truth', 'the reality',
                              'here is the truth', 'the result', 'the key'}
                if label.lower() not in skip_labels:
                    after_label = rest[m.end()-1:].strip()  # keep the space after colon
                    new_line = f"• **{label}:** {after_label.lstrip(': ')}"
                    # Preserve leading whitespace
                    lead = line[:len(line)-len(line.lstrip())]
                    new_lines.append(lead + new_line)
                    log(fp, cid, "ADD_BOLD_TO_LABEL", f"• {label}: → • **{label}:**")
                    changed = True
                    continue
        new_lines.append(line)
    
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 3: Fix missing space after bullet
# ════════════════════════════════════════════════════════════════════

def fix_bullet_no_space(text, fp, cid):
    """Add space after • when followed directly by non-space."""
    new_text = re.sub(r'•(\S)', r'• \1', text)
    if new_text != text:
        log(fp, cid, "ADD_SPACE_AFTER_BULLET", "Added space after •")
        return new_text
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 4: Normalize dash bullets to •
# ════════════════════════════════════════════════════════════════════

def fix_mixed_bullets(text, fp, cid):
    """Normalize - bullets to • where card uses both styles."""
    styles = set()
    for line in text.split('\n'):
        s = line.strip()
        if s.startswith('• '): styles.add('•')
        elif re.match(r'^-\s+\S', s): styles.add('-')
    
    if '•' in styles and '-' in styles:
        lines = text.split('\n')
        new_lines = []
        changed = False
        for line in lines:
            s = line.strip()
            if re.match(r'^-\s+\S', s):
                lead = line[:len(line)-len(line.lstrip())]
                new_lines.append(lead + '• ' + s[2:])
                log(fp, cid, "NORMALIZE_BULLET", f"- → • bullet")
                changed = True
            else:
                new_lines.append(line)
        if changed:
            return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 5: Fix bold colon outside
# ════════════════════════════════════════════════════════════════════

def fix_bold_colon_outside(text, fp, cid):
    """Fix **Label**: → **Label:** (move colon inside bold)."""
    new_text = re.sub(r'\*\*([^*\n]+)\*\*:', r'**\1:**', text)
    if new_text != text:
        # Count changes
        diffs = len(text) - len(new_text) if len(text) != len(new_text) else 1
        log(fp, cid, "MOVE_COLON_INSIDE_BOLD", "**Label**: → **Label:**")
        return new_text
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 6: Fix specific broken bold patterns
# ════════════════════════════════════════════════════════════════════

def fix_broken_bold(text, fp, cid):
    """Fix known broken bold patterns."""
    original = text
    
    # Pattern A: Missing opening ** on a line
    # "word** rest" at start of line where ** should wrap the word
    # e.g., "Internal processors** think before talking.**"
    # Should be: "**Internal processors** think before talking."
    # 
    # Detect: line that has ** but doesn't start with ** and has ** in middle of a word/phrase
    lines = text.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        s = line.strip()
        if not s:
            new_lines.append(line)
            continue
        
        # Pattern A1: "Word word** rest of text.**" → "**Word word** rest of text."
        # Line starts with alpha, has closing ** mid-line, may have trailing **
        m = re.match(r'^([A-Z][^*\n]+?)\*\*(\s.+?)\.\*\*$', s)
        if m and '**' not in m.group(1) and s.count('**') == 2:
            word = m.group(1).strip()
            rest = m.group(2).strip()
            new_s = f"**{word}** {rest}."
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "FIX_MISSING_OPEN_BOLD", f"'{s[:50]}' → '**{word}** ...'")
            changed = True
            continue
        
        # Pattern A2: "Word** → description.**" (e.g., "Erosion** → Fear of commitment.**")
        m = re.match(r'^([A-Z][a-z]+)\*\*(\s*→\s*.+?)\.\*\*$', s)
        if m:
            word = m.group(1)
            rest = m.group(2).strip()
            new_s = f"**{word}** {rest}."
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "FIX_MISSING_OPEN_BOLD", f"'{word}**' → '**{word}**'")
            changed = True
            continue
        
        # Pattern A3: "Word → ..." where parallel items are **Bold** → ... (missing bold entirely)
        # e.g., "Abuse → Tolerance..." where "**Betrayal** →" is the pattern
        # Check if this line starts with a single capitalized word followed by →
        # and other lines in the same card have **Word** → pattern
        m = re.match(r'^([A-Z][a-z]+)\s*→\s*(.+)$', s)
        if m:
            word = m.group(1)
            rest = m.group(2)
            # Check if other lines have **Word** → pattern
            has_bold_arrow = any(re.match(r'^\*\*[A-Z][a-z]+\*\*\s*→', l.strip()) for l in lines if l.strip() != s)
            if has_bold_arrow:
                new_s = f"**{word}** → {rest}"
                lead = line[:len(line)-len(line.lstrip())]
                new_lines.append(lead + new_s)
                log(fp, cid, "FIX_UNBOLD_PARALLEL", f"'{word} →' → '**{word}** →'")
                changed = True
                continue
        
        # Pattern B: "**You **verb phrase** ..." → "You **verb phrase** ..."
        # Opening ** before "You" that shouldn't be there
        new_s = re.sub(r'\*\*You \*\*', 'You **', s)
        if new_s != s:
            # Also remove trailing ** at end of sentence if it's orphaned
            # Count ** in new_s
            count = len(re.findall(r'\*\*', new_s))
            if count % 2 != 0 and new_s.endswith('**'):
                new_s = new_s[:-2].rstrip()
                if not new_s.endswith('.'):
                    new_s += '.'
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "FIX_YOU_BOLD", "**You ** → You **")
            changed = True
            continue
        
        # Pattern C: "Beneath the surface** (for X):**" → "**Beneath the surface (for X):**"
        m = re.match(r'^([A-Z][^*\n]+?)\*\*\s*(\([^)]+\)):\*\*(.*)$', s)
        if m:
            phrase = m.group(1).strip()
            paren = m.group(2)
            rest = m.group(3).strip()
            new_s = f"**{phrase} {paren}:** {rest}"
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "FIX_BROKEN_SURFACE", f"Fixed bold structure for '{phrase}...'")
            changed = True
            continue
        
        # Pattern D: "**Beneath the surface** (for X):** text**" 
        # Here we have an extra ** that opens bold on "I need..." and closes with trailing **
        m = re.match(r'^(\*\*[^*]+\*\*)\s*(\([^)]+\)):\*\*\s*(.+?)\*\*$', s)
        if m:
            bold_part = m.group(1)
            paren = m.group(2)
            rest = m.group(3)
            # Merge into one bold span
            inner = re.sub(r'^\*\*|\*\*$', '', bold_part)
            new_s = f"**{inner} {paren}:** {rest}"
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "FIX_BROKEN_SURFACE_D", f"Fixed double-bold structure")
            changed = True
            continue
        
        # Pattern E: line with "I need some space to decompress.** I am overwhelmed..."
        # Stray ** in middle of sentence
        m = re.search(r'(\w+\.)\*\*\s+([A-Z])', s)
        if m and s.count('**') == 1:  # Only one ** on the line = stray
            new_s = s.replace('**', '')
            lead = line[:len(line)-len(line.lstrip())]
            new_lines.append(lead + new_s)
            log(fp, cid, "REMOVE_STRAY_BOLD", f"Removed stray ** from middle of text")
            changed = True
            continue
        
        new_lines.append(line)
    
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 7: Split wall-of-text in summary cards
# ════════════════════════════════════════════════════════════════════

def fix_wall_of_text(text, fp, cid):
    """Split very long lines that contain multiple sentences with 'You **verb**' pattern."""
    lines = text.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        s = line.strip()
        # Only process very long lines (>300 chars) that have the "You **" pattern
        if len(s) > 300 and 'You **' in s:
            # Split at "You **" boundaries (but keep the "You **" as part of each section)
            parts = re.split(r'(?=You \*\*)', s)
            if len(parts) > 1:
                lead = line[:len(line)-len(line.lstrip())]
                for i, part in enumerate(parts):
                    part = part.strip()
                    if part:
                        new_lines.append(lead + part)
                        if i < len(parts) - 1:
                            new_lines.append('')  # blank line between
                log(fp, cid, "SPLIT_WALL", f"Split {len(s)} char line into {len(parts)} paragraphs")
                changed = True
                continue
        
        new_lines.append(line)
    
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 8: Fix merged lines (Fun practices + restore practices)
# ════════════════════════════════════════════════════════════════════

def fix_merged_lines(text, fp, cid):
    """Fix lines that have been improperly merged together."""
    lines = text.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        s = line.strip()
        
        # Pattern: "**Label: stuff **another label:stuff" — two bold labels merged
        # Look for **close immediately followed by lowercase word or **open
        if '**' in s and len(s) > 150:
            # Try to split at points where one section ends and another begins
            # Pattern: "stuff? **next section:..."
            parts = re.split(r'(\?\s*\*\*[a-z])', s)
            if len(parts) > 1:
                # Reconstruct with line breaks
                lead = line[:len(line)-len(line.lstrip())]
                result_lines = []
                current = ""
                for i, part in enumerate(parts):
                    current += part
                    # Check if this part ends with "? **" pattern (split point)
                    if re.search(r'\?\s*$', part) and i < len(parts) - 1:
                        result_lines.append(current.rstrip())
                        result_lines.append('')
                        current = ""
                if current.strip():
                    result_lines.append(current)
                
                if len(result_lines) > 1:
                    for rl in result_lines:
                        new_lines.append(lead + rl if rl.strip() else '')
                    log(fp, cid, "SPLIT_MERGED", f"Split merged line into {len([r for r in result_lines if r.strip()])} parts")
                    changed = True
                    continue
        
        new_lines.append(line)
    
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 9: Fix inline numbered lists
# ════════════════════════════════════════════════════════════════════

def fix_inline_numbered(text, fp, cid):
    """Split inline numbered items onto separate lines."""
    lines = text.split('\n')
    new_lines = []
    changed = False
    
    for line in lines:
        # Check for inline pattern: "text 1. item 2. item"
        nums = list(re.finditer(r'(?:^|\s)(\d+)\.\s+', line))
        if len(nums) >= 2:
            ints = [int(m.group(1)) for m in nums]
            sequential = any(ints[i]+1 == ints[i+1] for i in range(len(ints)-1))
            if sequential:
                # Split at each number
                lead = line[:len(line)-len(line.lstrip())]
                parts = re.split(r'\s+(?=\d+\.\s)', line.strip())
                if len(parts) > 1:
                    # First part might be introductory text
                    for i, part in enumerate(parts):
                        new_lines.append(lead + part.strip())
                        if i < len(parts) - 1:
                            new_lines.append('')
                    log(fp, cid, "SPLIT_INLINE_NUMBERED", f"Split {len(parts)} numbered items")
                    changed = True
                    continue
        
        new_lines.append(line)
    
    if changed:
        return '\n'.join(new_lines)
    return text


# ════════════════════════════════════════════════════════════════════
# PASS 10: Clean up trailing/leading whitespace and excess newlines
# ════════════════════════════════════════════════════════════════════

def fix_whitespace(text, fp, cid):
    """Fix trailing whitespace and excessive newlines."""
    original = text
    
    # Fix trailing whitespace on each line
    lines = text.split('\n')
    text = '\n'.join(l.rstrip() for l in lines)
    
    # Fix double spaces
    while '  ' in text:
        text = text.replace('  ', ' ')
    
    # Fix excessive newlines (>2 consecutive)
    while '\n\n\n\n' in text:
        text = text.replace('\n\n\n\n', '\n\n\n')
    
    # Strip leading/trailing whitespace from whole text
    text = text.strip()
    
    if text != original:
        log(fp, cid, "FIX_WHITESPACE", "Cleaned whitespace")
    
    return text


# ════════════════════════════════════════════════════════════════════
# MAIN PROCESSING
# ════════════════════════════════════════════════════════════════════

def fix_text(text, filepath, card_id):
    """Apply all fix passes to a text field."""
    if not text or not isinstance(text, str) or not text.strip():
        return text
    
    original = text
    
    # Order matters!
    text = fix_empty_bullets(text, filepath, card_id)
    text = fix_bullet_no_space(text, filepath, card_id)
    text = fix_broken_bold(text, filepath, card_id)
    text = fix_bold_colon_outside(text, filepath, card_id)
    text = fix_mixed_bullets(text, filepath, card_id)
    text = fix_bullet_label_no_bold(text, filepath, card_id)
    text = fix_wall_of_text(text, filepath, card_id)
    text = fix_merged_lines(text, filepath, card_id)
    text = fix_inline_numbered(text, filepath, card_id)
    text = fix_whitespace(text, filepath, card_id)
    
    return text


def process_file(filepath):
    """Process all cards in a file."""
    global files_modified
    fname = os.path.basename(filepath)
    
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original_json = json.dumps(data, ensure_ascii=False)
    
    # Process all activities → cards
    for act in data.get("activities", []):
        act_id = act.get("id", "?")
        for card in act.get("cards", []):
            card_id = card.get("cardId", card.get("id", "?"))
            
            # Fix text field
            if "text" in card and card["text"]:
                card["text"] = fix_text(card["text"], filepath, card_id)
            
            # Fix reflection field
            if "reflection" in card and isinstance(card["reflection"], str) and card["reflection"]:
                card["reflection"] = fix_text(card["reflection"], filepath, card_id)
    
    new_json = json.dumps(data, ensure_ascii=False)
    if new_json != original_json:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        files_modified += 1
        return True
    return False


# ════════════════════════════════════════════════════════════════════
# RUN
# ════════════════════════════════════════════════════════════════════

print("=" * 70)
print("WORLD-CLASS CONTENT FIXER v3")
print("=" * 70)

for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    
    files = sorted(folder_path.glob("*.json"))
    print(f"\n📁 {folder}/")
    
    for filepath in files:
        before_count = total_fixes
        modified = process_file(str(filepath))
        after_count = total_fixes
        fix_count = after_count - before_count
        
        if modified:
            print(f"  🔧 {filepath.name} ({fix_count} fixes)")
        else:
            print(f"  ✅ {filepath.name}")

# JSON validation
print(f"\n{'─' * 70}")
print("JSON VALIDATION")
json_errors = 0
for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    for f in sorted(folder_path.glob("*.json")):
        try:
            with open(f) as fh:
                json.load(fh)
        except json.JSONDecodeError as e:
            print(f"  ❌ {f.name}: {e}")
            json_errors += 1

if json_errors == 0:
    print("  ✅ All files valid JSON")
else:
    print(f"  ❌ {json_errors} JSON errors!")

# Summary
print(f"\n{'=' * 70}")
print(f"SUMMARY")
print(f"  Files modified: {files_modified}/65")
print(f"  Total fixes: {total_fixes}")
print(f"  JSON errors: {json_errors}")
print(f"{'=' * 70}")

# Fix type breakdown
from collections import defaultdict
type_counts = defaultdict(int)
for fix in fix_log:
    type_counts[fix["type"]] += 1

print(f"\nFix breakdown:")
for ftype, count in sorted(type_counts.items(), key=lambda x: -x[1]):
    print(f"  {ftype}: {count}")

# Show first 5 of each type as examples
print(f"\nExamples:")
shown = defaultdict(int)
for fix in fix_log:
    if shown[fix["type"]] < 2:
        print(f"  [{fix['type']}] {fix['file']} {fix['card']}: {fix['detail']}")
        shown[fix["type"]] += 1

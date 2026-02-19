#!/usr/bin/env python3
"""
World-Class Content Fixer v3 - Round 2
======================================
Targeted fixes for remaining issues after Round 1.

1. Fix merged line in singles_journey_04 c3 (Fun practices + restore practices)
2. Split wall-of-text c6 commitment cards
3. Fix orphan quotes where clearly broken
"""

import json, os, re, glob
from pathlib import Path

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

total_fixes = 0
files_modified = 0

def log(msg):
    global total_fixes
    total_fixes += 1
    print(f"  🔧 {msg}")

# ════════════════════════════════════════════════════════════════════
# FIX 1: Merged line in singles_journey_04 c3
# ════════════════════════════════════════════════════════════════════

def fix_merged_fun_practices():
    """Fix the merged 'Fun practices' + 'restore practices' line."""
    filepath = str(BASE / "singles journeys" / "singles_journey_04_family_patterns.json")
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    changed = False
    for act in data.get("activities", []):
        if "act_10" not in act.get("id", ""):
            continue
        for card in act.get("cards", []):
            if card.get("cardId") != "c3":
                continue
            text = card.get("text", "")
            # Find the merged line: "**Fun practices:...** **restore practices:..."
            # Also need to fix the other practice labels to be consistent
            old = text
            
            # The merged line has "**Fun practices:" on it AND "restore practices:" merged
            # Fix: split into separate lines with consistent bold labels
            lines = text.split('\n')
            new_lines = []
            for line in lines:
                s = line.strip()
                # Fix the merged Fun/Restore line
                if '**Fun practices:' in s and 'restore practices:' in s.lower():
                    # Extract parts
                    m = re.match(r'\*\*Fun practices:\s*(.*?)\s*\*\*\s*restore practices:\s*(.*)', s, re.IGNORECASE)
                    if m:
                        fun_content = m.group(1).strip()
                        restore_content = m.group(2).strip()
                        new_lines.append(f"**Fun practices:** {fun_content}")
                        new_lines.append("")
                        new_lines.append(f"**Restore practices:** {restore_content}")
                        log("Split merged Fun/Restore practices line")
                        changed = True
                        continue
                
                # Also bold the other practice labels for consistency
                # Check if line starts with "X practices:" without bold
                m2 = re.match(r'^(Communication|Conflict|Affection|Faith)\s+practices:\s*(.+)$', s)
                if m2:
                    label = m2.group(1)
                    content = m2.group(2)
                    new_lines.append(f"**{label} practices:** {content}")
                    log(f"Bolded '{label} practices:' for consistency")
                    changed = True
                    continue
                
                new_lines.append(line)
            
            if changed:
                card["text"] = '\n'.join(new_lines)
    
    if changed:
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')
        return True
    return False


# ════════════════════════════════════════════════════════════════════
# FIX 2: Split wall-of-text c6 commitment cards  
# ════════════════════════════════════════════════════════════════════

def fix_wall_of_text_commitments():
    """Split very long commitment paragraphs in c6 cards."""
    changed_files = []
    
    for folder in FOLDERS:
        folder_path = BASE / folder
        if not folder_path.exists():
            continue
        
        for filepath in sorted(folder_path.glob("*.json")):
            with open(filepath, 'r') as f:
                data = json.load(f)
            
            file_changed = False
            for act in data.get("activities", []):
                for card in act.get("cards", []):
                    text = card.get("text", "")
                    if not text:
                        continue
                    
                    # Find lines > 400 chars that have "We commit" pattern
                    lines = text.split('\n')
                    new_lines = []
                    for line in lines:
                        s = line.strip()
                        if len(s) > 400 and 'We commit' in s:
                            # Split at "We commit to" boundaries
                            parts = re.split(r'(?=We commit to\s)', s)
                            if len(parts) > 1:
                                lead = line[:len(line)-len(line.lstrip())]
                                for i, part in enumerate(parts):
                                    part = part.strip()
                                    if part:
                                        new_lines.append(lead + part)
                                        if i < len(parts) - 1:
                                            new_lines.append('')
                                log(f"Split {len(s)} char commitment paragraph into {len([p for p in parts if p.strip()])} items")
                                file_changed = True
                                continue
                        
                        new_lines.append(line)
                    
                    if file_changed:
                        card["text"] = '\n'.join(new_lines)
            
            if file_changed:
                with open(filepath, 'w') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                    f.write('\n')
                changed_files.append(filepath.name)
    
    return changed_files


# ════════════════════════════════════════════════════════════════════
# FIX 3: Fix orphan quotes 
# ════════════════════════════════════════════════════════════════════

def fix_orphan_quotes():
    """Fix clearly broken orphan quotes.
    
    Strategy:
    - Count=1 with single " at start of text → likely missing opening context (leave alone — stylistic)
    - Lines that start with " but never close → add closing "
    - Lines that have quotes wrapping phrases but one is missing
    """
    fixed_count = 0
    changed_files = []
    
    for folder in FOLDERS:
        folder_path = BASE / folder
        if not folder_path.exists():
            continue
        
        for filepath in sorted(folder_path.glob("*.json")):
            with open(filepath, 'r') as f:
                data = json.load(f)
            
            file_changed = False
            for act in data.get("activities", []):
                for card in act.get("cards", []):
                    text = card.get("text", "")
                    if not text:
                        continue
                    
                    count = text.count('"')
                    if count % 2 == 0:
                        continue  # Even = OK
                    
                    cid = card.get("cardId", card.get("id", "?"))
                    
                    # Strategy: look at each line for obvious orphan
                    lines = text.split('\n')
                    new_lines = []
                    fixed_this_card = False
                    
                    for line in lines:
                        s = line.strip()
                        if not s:
                            new_lines.append(line)
                            continue
                        
                        line_quotes = s.count('"')
                        
                        # Single quote on a line — find it and fix
                        if line_quotes == 1:
                            # Pattern: line starts with " but doesn't close
                            # "Just move on.  → "Just move on."
                            if s.startswith('"') and not s.endswith('"'):
                                # Check if it's a short phrase that should be in quotes
                                # Don't add closing " if line is very long (might be intentional)
                                if len(s) < 80:
                                    lead = line[:len(line)-len(line.lstrip())]
                                    # Check if it ends with punctuation
                                    if s[-1] in '.!?':
                                        new_s = s[:-1] + s[-1]  # Already has punctuation, just needs closing "
                                        # Actually: "word." → no change needed, "word. → "word."
                                        # The quote is at start, must add close before or after period
                                        # "Just move on. → "Just move on."
                                        new_s = s.rstrip('.!?,;:') + '"' + s[len(s.rstrip('.!?,;:')):]
                                        if new_s[-1] != '"' and new_s.count('"') == 2:
                                            pass  # good
                                        elif s[-1] in '.!?':
                                            new_s = s[:-1] + '"' + s[-1]
                                        else:
                                            new_s = s + '"'
                                    else:
                                        new_s = s + '"'
                                    
                                    # Verify we now have even quotes
                                    if new_s.count('"') % 2 == 0:
                                        new_lines.append(lead + new_s)
                                        log(f"Added closing \" to '{s[:40]}' in {filepath.name} {cid}")
                                        fixed_this_card = True
                                        fixed_count += 1
                                        continue
                            
                            # Pattern: line ends with " but doesn't start with one (closing without opening)
                            if s.endswith('"') and not s.startswith('"') and '"' in s:
                                # Find the " and check context
                                qi = s.index('"')
                                before = s[:qi]
                                # If it looks like a word before " that should have opening "(e.g., "said word")
                                pass  # Too complex — skip
                        
                        new_lines.append(line)
                    
                    if fixed_this_card:
                        card["text"] = '\n'.join(new_lines)
                        file_changed = True
            
            if file_changed:
                with open(filepath, 'w') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                    f.write('\n')
                changed_files.append(filepath.name)
    
    return fixed_count, changed_files


# ════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════

print("=" * 70)
print("WORLD-CLASS CONTENT FIXER v3 - ROUND 2")
print("=" * 70)

# Fix 1
print("\n📋 FIX 1: Merged line in singles_journey_04 c3")
if fix_merged_fun_practices():
    print("  ✅ Fixed merged Fun/Restore practices line")
else:
    print("  ℹ️  No change needed")

# Fix 2
print("\n📋 FIX 2: Split wall-of-text commitment paragraphs")
changed = fix_wall_of_text_commitments()
if changed:
    for fn in changed:
        print(f"  ✅ Split commitment paragraph in {fn}")
else:
    print("  ℹ️  No walls of text found")

# Fix 3  
print("\n📋 FIX 3: Fix orphan quotes")
count, changed = fix_orphan_quotes()
print(f"  Fixed {count} orphan quotes in {len(changed)} files")

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

print(f"\n{'=' * 70}")
print(f"SUMMARY: {total_fixes} fixes applied, {json_errors} JSON errors")
print(f"{'=' * 70}")

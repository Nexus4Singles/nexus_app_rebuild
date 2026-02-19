#!/usr/bin/env python3
"""
Fix remaining scripture quotes missing opening " mark.

Pattern: Line starts with scripture text and contains '" ({red|..})' or starts
with scripture text and ends with '"' but has no matching opening '"'.

This handles lines within card text that look like:
  The Son of Man did not come to be served, but to serve." ({red|Mark 10:45})
  → "The Son of Man did not come to be served, but to serve." ({red|Mark 10:45})
"""

import json, os, re, glob
from pathlib import Path

BASE = Path("assets/config/journeys")
FOLDERS = ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]

fixes = 0
files_fixed = set()

for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    for fp in sorted(folder_path.glob("*.json")):
        with open(fp, 'r', encoding='utf-8') as f:
            raw = f.read()
        
        data = json.loads(raw)
        changed = False
        
        for act in data.get("activities", []):
            for card in act.get("cards", []):
                cid = card.get("cardId") or card.get("id", "?")
                
                for field in ["text", "reflection"]:
                    text = card.get(field)
                    if not text or text.count('"') % 2 == 0:
                        continue
                    
                    # Split into lines and find lines with odd quote count
                    lines = text.split('\n')
                    new_lines = list(lines)
                    line_fixed = False
                    
                    for i, line in enumerate(lines):
                        stripped = line.strip()
                        if not stripped:
                            continue
                        
                        line_quotes = stripped.count('"')
                        if line_quotes % 2 == 0:
                            continue
                        
                        # Pattern 1: Scripture closing — line has '" ({red|..})' or '" ()' 
                        # but no opening '"' before the quote text on this line
                        scripture_match = re.search(r'"[\s]*\({red\|[^}]+\}\)', stripped)
                        empty_ref_match = re.search(r'"[\s]*\(\)', stripped)
                        
                        if scripture_match or empty_ref_match:
                            # Check if there's an opening " on this line
                            # The " before ({red|..}) is a closing quote
                            # Count: if there's only 1 " (or odd count), it's missing opening
                            
                            # Find where the scripture quote starts on this line
                            # It should be the text before the closing "
                            # If the line starts without ", add one at the beginning
                            clean = stripped.lstrip('• *-').strip()
                            if not clean.startswith('"'):
                                # Need to add opening " at beginning of meaningful content
                                # Find the position in the original line where content starts
                                leading = len(line) - len(line.lstrip())
                                prefix = line[:leading]
                                content = line[leading:]
                                
                                # If content starts with bullet markers, add " after them
                                bullet_match = re.match(r'^([•\*\-]\s*)', content)
                                if bullet_match:
                                    bullet = bullet_match.group(1)
                                    rest = content[len(bullet):]
                                    new_lines[i] = prefix + bullet + '"' + rest
                                else:
                                    new_lines[i] = prefix + '"' + content
                                
                                line_fixed = True
                                fixes += 1
                                files_fixed.add(fp.name)
                                print(f"  FIX [{fp.name}] {cid}/{field} L{i}: Added opening \" for scripture")
                                print(f"    OLD: {stripped[:100]}")
                                print(f"    NEW: {new_lines[i].strip()[:100]}")
                                continue
                        
                        # Pattern 2: Line has only closing " (ends with " or has " mid-line)
                        # and the quote might span from a previous line
                        # For multi-line quotes that started on a previous line (already has
                        # opening "), skip — the overall card count being odd suggests
                        # one more issue. Check if any preceding line has an opening "
                        # that hasn't been closed yet.
                        # This is complex — skip for safety and handle manually if needed.
                    
                    if line_fixed:
                        card[field] = '\n'.join(new_lines)
                        changed = True
        
        if changed:
            with open(fp, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            print(f"  → Saved {fp.name}")

print(f"\nTotal fixes: {fixes}")
print(f"Files fixed: {len(files_fixed)}")

# Validate JSON
errors = 0
for folder in FOLDERS:
    folder_path = BASE / folder
    if not folder_path.exists():
        continue
    for fp in sorted(folder_path.glob("*.json")):
        try:
            with open(fp) as f:
                json.load(f)
        except Exception as e:
            errors += 1
            print(f"JSON ERROR: {fp.name}: {e}")
print(f"JSON errors: {errors}")

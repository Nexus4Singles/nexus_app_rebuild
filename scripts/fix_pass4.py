#!/usr/bin/env python3
"""
Pass 4: Fix the final 23 unpaired bold patterns.
All remaining patterns fall into a few categories:
  1. word:** text  →  word: text   (remove stray ** after colon)
  2. word:**text   →  word: text   (remove ** + add space)
  3. : ** text     →  : text       (remove stray ** between colon and text)
  4. You **word    →  You word     (lone ** before word)
  5. word**\n      →  word\n       (trailing **)
  6. }:** 'text    →  }): 'text    (red tag + stray bold)
"""
import json, re
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journeys"
MAP_FILE = Path(__file__).resolve().parent.parent / "assets" / "config" / "journey_id_filename_map.json"
FOLDERS = {
    "singles": BASE / "singles journeys",
    "married": BASE / "married journeys",
    "divorced": BASE / "divorced journeys",
    "widowed": BASE / "widowed journeys",
}
with open(MAP_FILE) as f: FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())

def get_all_active_files():
    files = []
    for folder in FOLDERS.values():
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES: files.append((fp, fp.name))
    return files


def fix_text(text):
    if not text or not text.strip():
        return text
    
    # Type 1: word:** text  →  word: text
    # Handles: quiet:** a, requests:** what, truth:** on, easily:** Brian, etc.
    text = re.sub(r'(\w)\*\*:\s+', r'\1: ', text)
    
    # Type 2: word:**text  →  word: text  (no space after colon)
    # Handles: distortions:**Hyper, accountability:**Filters, provides:**Immediate, options:**"I am
    text = re.sub(r'(\w)\*\*:(\S)', r'\1: \2', text)
    
    # Type 3: : ** text  →  : text  (stray ** between colon and quote/text)
    # Handles: Needs/Fears: ** 'I'm, Baptist: ** services, wrote: ** 'Between
    text = re.sub(r':\s+\*\*\s+', ': ', text)
    
    # Type 4: bullet with stray bold before colon: • Reflect back:** "So  →  • Reflect back: "So
    # Already handled by Type 1 (word**:)
    
    # Type 5: }:** text  →  }): text  (red tag closing + stray bold around colon)
    text = re.sub(r'\}\*\*:\s*', '}): ', text)
    
    # Type 6: lone ** before a word mid-sentence: "You **examined" → "You examined"
    # Match: space + ** + word (where ** is not paired)
    # Be careful not to remove valid bold pairs
    
    # Type 7: trailing ** at end of line
    lines = text.split('\n')
    for i, line in enumerate(lines):
        stripped = line.strip()
        count = stripped.count('**')
        if count % 2 != 0:
            # Trailing ** with no partner
            if stripped.endswith('**') and count == 1:
                lines[i] = stripped[:-2].rstrip()
            # Leading lone ** with no close
            elif count == 1:
                pos = stripped.find('**')
                # If it's mid-sentence like "You **examined specific"
                # Remove the lone **
                before = stripped[:pos]
                after = stripped[pos+2:]
                # Is ** at a word boundary?
                if (pos == 0 or before[-1] in ' \t') and after and after[0] not in ' \t':
                    lines[i] = before + after
                elif after and after[0] in ' \t':
                    lines[i] = before + after
            # 3 markers: like **text** extra**
            elif count == 3:
                if stripped.endswith('**'):
                    lines[i] = stripped[:-2].rstrip()
            # 5 markers: like **text** more **text** extra**
            elif count == 5:
                if stripped.endswith('**'):
                    lines[i] = stripped[:-2].rstrip()
    
    text = '\n'.join(lines)
    
    # Type 8: 'think:**' without space → 'think:** '
    text = re.sub(r'\*\*:\'', ":** '", text)
    
    # Type 9: 'realize:**' mid-word → fix
    text = re.sub(r'(\w):\*\*\s*', r'\1: ', text)
    
    # Clean up any quadruple asterisks
    text = re.sub(r'\*{4,}', '**', text)
    
    return text


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 4)...\n")
    
    modified_count = 0
    for filepath, filename in files:
        with open(filepath) as f: data = json.load(f)
        modified = False
        
        def process_cards(cards):
            nonlocal modified
            for card in cards:
                for field in ["text", "prompt", "reflection"]:
                    if field in card and card[field] and isinstance(card[field], str):
                        original = card[field]
                        fixed = fix_text(original)
                        if fixed != original:
                            card[field] = fixed
                            modified = True
        
        for act in data.get("activities", []):
            process_cards(act.get("cards", []))
        for mission in data.get("missions", []):
            process_cards(mission.get("cards", []))
        
        if modified:
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
                f.write('\n')
            modified_count += 1
            print(f"  ✓ {filename}")
    
    print(f"\nModified {modified_count}/{len(files)} files.")
    
    errors = 0
    for filepath, filename in files:
        try:
            with open(filepath) as f: json.load(f)
        except json.JSONDecodeError as e:
            print(f"  ✗ JSON ERROR: {filename}: {e}")
            errors += 1
    print(f"JSON validation: {errors} errors")

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Pass 3: Fix remaining unpaired bold patterns and the last inline bullet.
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


def fix_remaining_bold(text):
    """Fix specific unpaired bold patterns that pass 2 missed."""
    
    # Pattern A: mid-line numbered items with bold opening
    # "text: **1. Title\n..." → "text:\n\n**1. Title**\n..."
    # Split the line and close bold on the title
    def split_numbered_bold(m):
        prefix = m.group(1)
        number = m.group(2)
        title = m.group(3)
        return f'{prefix}\n\n**{number}. {title}**'
    
    text = re.sub(
        r'([^*\n]{10,})\s+\*\*(\d+)\.\s+([^\n]+)',
        split_numbered_bold,
        text
    )
    
    # Pattern B: "text." **N. Title" on same line 
    # 'origin." **3. Recognize' → 'origin."\n\n**3. Recognize**'
    text = re.sub(
        r'([."\'!?])\s+\*\*(\d+)\.\s+([^\n]+)',
        lambda m: f'{m.group(1)}\n\n**{m.group(2)}. {m.group(3)}**',
        text
    )
    
    # Pattern C: 'Label**:' or 'label**looks' → fix bold position
    # 'Gridlock**looks like:' → '**Gridlock** looks like:'
    # 'easily:** Brian' → 'easily: Brian'
    text = re.sub(r'(\w)\*\*:\s*', r'\1: ', text)  # word**:  → word: 
    text = re.sub(r'(\w)\*\*(\s*looks)', r'\1\2', text)  # word**looks → word looks
    
    # Pattern D: 'phrase"** → ' (closing bold after quote)
    # '"Waiting is repression"** → No' → '"Waiting is repression" → No' (remove orphan **)
    text = re.sub(r'"\*\*\s*→', '" →', text)
    
    # Pattern E: '• Label:**text' → '• **Label:** text'
    text = re.sub(r'(•\s*)(\w[^*\n]+)\*\*([\'"])', r'\1**\2**\3', text)
    
    # Pattern F: '• Reflect back:** "So' → '• **Reflect back:** "So'
    text = re.sub(r'(•\s*)(\w[^*\n]+)\*\*:\s*', r'\1**\2:** ', text)
    
    # Pattern G: stray }' inside text (from broken red tag remnants)
    text = re.sub(r"\{red\|[^}]*\}\s*'\s*\d+\.", lambda m: m.group(0) if '{red|' in m.group(0) else m.group(0), text)
    
    # Now re-check: any remaining lines with odd ** count
    lines = text.split('\n')
    for i, line in enumerate(lines):
        stripped = line.strip()
        count = stripped.count('**')
        if count % 2 != 0 and count > 0:
            # Try to fix remaining cases
            
            # If there's a ** at end with no partner → remove it
            if stripped.endswith('**') and count == 1:
                lines[i] = stripped[:-2]
            # If there's a ** at start with no partner → remove it
            elif stripped.startswith('**') and count == 1:
                rest = stripped[2:]
                if len(rest) < 60:
                    lines[i] = f'**{rest}**'
                else:
                    lines[i] = rest
            # 3 markers: likely xx**yy**zz** or **xx**yy** pattern
            elif count == 3:
                # Find positions
                positions = [m.start() for m in re.finditer(r'\*\*', stripped)]
                # Try removing the last one if it's at end
                if positions[-1] == len(stripped) - 2:
                    lines[i] = stripped[:-2]
                # Or remove the first one if at start
                elif positions[0] == 0:
                    lines[i] = stripped[2:]
    
    text = '\n'.join(lines)
    
    # Clean up: fix any double bold markers that appeared
    text = re.sub(r'\*{4,}', '**', text)
    
    # Clean double newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    return text


def fix_remaining_bullets(text):
    """Fix remaining inline bullet patterns."""
    lines = text.split('\n')
    new_lines = []
    
    for line in lines:
        stripped = line.strip()
        # Pattern: "text - item1 Connector: - item2"
        # Split on instances of " - " that introduce list items
        if stripped.count(' - ') >= 1 and len(stripped) > 80:
            # Check if there are labeled sections separated by whitespace
            parts = re.split(r'\s+(?=-\s)', stripped)
            if len(parts) >= 2 and any(p.startswith('- ') for p in parts[1:]):
                for p in parts:
                    new_lines.append(p)
                continue
        
        new_lines.append(line)
    
    return '\n'.join(new_lines)


def process_text(text):
    if not text or not text.strip():
        return text
    t = fix_remaining_bold(text)
    t = fix_remaining_bullets(t)
    return t.strip()


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 3)...\n")
    
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
                        fixed = process_text(original)
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

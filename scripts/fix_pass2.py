#!/usr/bin/env python3
"""
Pass 2 fixes: remaining orphan quotes, unpaired bold, inline bullets.
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


def fix_orphan_quotes(text):
    """Fix lone " on its own line by merging with adjacent text."""
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped in ('"', '\u201c', '\u201d'):
            # Determine if opening or closing quote
            if i + 1 < len(lines) and lines[i+1].strip():
                # Has text after → opening quote → prepend to next line
                lines[i+1] = '"' + lines[i+1].lstrip()
                lines[i] = ''
            elif i > 0 and lines[i-1].strip():
                # Has text before → closing quote → append to prev line
                lines[i-1] = lines[i-1].rstrip() + '"'
                lines[i] = ''
            else:
                # Completely isolated → just remove
                lines[i] = ''
        i += 1
    
    # Clean up empty lines that result from removal
    text = '\n'.join(lines)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text


def fix_unpaired_bold(text):
    """Fix unpaired ** bold markers."""
    lines = text.split('\n')
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        count = stripped.count('**')
        if count == 0 or count % 2 == 0:
            continue
        
        # Pattern 1: **Numbered item title (no closing)
        # e.g. "**1. The Explosion Pattern" or "**1. Soft Start-Up"
        m = re.match(r'^(\*\*)(\d+\.\s+.+)$', stripped)
        if m:
            content = m.group(2)
            # Bold just the title part (up to first sentence end or limited length)
            # Find where the "title" part ends
            title_end = re.search(r'[.!?:\n]', content)
            if title_end and title_end.start() < 60:
                title = content[:title_end.start() + 1]
                rest = content[title_end.start() + 1:]
                lines[i] = f'**{title}**{rest}'
            elif len(content) < 80:
                lines[i] = f'**{content}**'
            else:
                # Too long to bold, just remove the opening **
                lines[i] = content
            continue
        
        # Pattern 2: Line starts with ** and has another ** pair inside
        # e.g. "**You **named wounds** you'd been avoiding"
        # The first ** is orphaned; the inner pair is correct
        if stripped.startswith('**') and count >= 3:
            # Remove the leading ** (the inner pairs are correct)
            rest = stripped[2:]
            if rest.count('**') % 2 == 0:
                lines[i] = rest
                continue
        
        # Pattern 3: Line ends with .**" or similar with closure issues
        # e.g. 'This always happens to me.** I was completely innocent."'
        if '.**' in stripped and count == 1:
            # The .** is a stray closing bold
            lines[i] = stripped.replace('.**', '.', 1)
            continue
        
        # Pattern 4: Line ends with **
        if stripped.endswith('**') and count == 1:
            # Orphan closing ** at end
            lines[i] = stripped[:-2]
            continue
            
        # Pattern 5: Line starts with ** only (opening orphan)
        if stripped.startswith('**') and count == 1:
            rest = stripped[2:]
            # If short enough to be a label/heading, add closing
            if len(rest) < 60:
                # Check if it ends with punctuation
                if rest.rstrip().endswith(('.', ':', '!', '?')):
                    lines[i] = f'**{rest}**'
                else:
                    lines[i] = rest  # Just remove orphan **
            else:
                lines[i] = rest  # Too long, remove **
            continue
    
    return '\n'.join(lines)


def fix_inline_bullets(text):
    """Split inline bullet items onto separate lines."""
    lines = text.split('\n')
    new_lines = []
    
    for line in lines:
        # Check for inline dash bullets: "text - item1 - item2 - item3"
        # Only if there are 2+ bullet dashes after some initial text
        stripped = line.strip()
        
        # Pattern: "Label: - item1 - item2 - item3"
        m = re.match(r'^(.+?:\s*)(-\s.+)', stripped)
        if m and m.group(2).count(' - ') >= 1:
            prefix = m.group(1)
            items_text = m.group(2)
            items = re.split(r'\s*-\s+', items_text)
            items = [it.strip() for it in items if it.strip()]
            if len(items) >= 2:
                new_lines.append(prefix)
                for item in items:
                    new_lines.append(f'- {item}')
                continue
        
        # Pattern: "text - item1 - item2" with multiple dashes in running text
        dash_items = re.split(r'\s+-\s+', stripped)
        if len(dash_items) >= 3 and len(stripped) > 60:
            # First part is the intro text
            new_lines.append(dash_items[0])
            for item in dash_items[1:]:
                new_lines.append(f'- {item}')
            continue
        
        # Pattern: items separated by " Acceptable " or similar connectors
        # "- item1 connector: - item2" 
        if re.findall(r'-\s\S+', stripped) and stripped.count(' - ') >= 1:
            # More nuanced splitting for complex patterns
            pass  # Let the above patterns handle it
        
        new_lines.append(line)
    
    return '\n'.join(new_lines)


def process_text(text):
    if not text or not text.strip():
        return text
    t = text
    t = fix_orphan_quotes(t)
    t = fix_unpaired_bold(t)
    t = fix_inline_bullets(t)
    # Final cleanup
    t = re.sub(r'\n{3,}', '\n\n', t)
    t = t.strip()
    return t


def main():
    files = get_all_active_files()
    print(f"Processing {len(files)} files (pass 2)...\n")
    
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
                if "bullets" in card and card["bullets"]:
                    for i, b in enumerate(card["bullets"]):
                        if isinstance(b, str):
                            fixed = process_text(b)
                            if fixed != b:
                                card["bullets"][i] = fixed
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
    
    # Validate
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

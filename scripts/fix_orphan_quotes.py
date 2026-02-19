#!/usr/bin/env python3
"""Fix orphan quotes: lines ending with " that don't start with "."""
import json, re, glob

total_fixes = 0
files_modified = 0

for f in sorted(glob.glob("assets/config/journeys/**/*.json", recursive=True)):
    with open(f) as fh:
        data = json.load(fh)
    
    fname = f.split('/')[-1]
    file_changed = False
    
    for act in data.get("activities", []):
        for card in act.get("cards", []):
            text = card.get("text", "")
            if not text:
                continue
            
            count = text.count('"')
            if count % 2 == 0:
                continue
            
            cid = card.get("cardId", card.get("id", "?"))
            lines = text.split('\n')
            new_lines = []
            card_changed = False
            
            for line in lines:
                s = line.strip()
                if not s:
                    new_lines.append(line)
                    continue
                
                lcount = s.count('"')
                
                # Pattern: line ends with ." or " or !" or ?" but has no opening "
                if lcount == 1 and (s.endswith('"') or s.endswith('."') or s.endswith('!"') or s.endswith('?"')):
                    # Check it doesn't already start with "
                    core = s.lstrip('• ').lstrip('- ')
                    if not core.startswith('"'):
                        # Add opening " at the start of the content
                        lead = line[:len(line)-len(line.lstrip())]
                        if s.startswith('• '):
                            # Bullet: • text" → • "text"
                            content = s[2:].strip()
                            new_s = f'• "{content}'
                        elif s.startswith('- '):
                            content = s[2:].strip()
                            new_s = f'- "{content}'
                        else:
                            new_s = f'"{s}'
                        
                        # Verify the fix makes quotes even on this line
                        if new_s.count('"') % 2 == 0:
                            new_lines.append(lead + new_s)
                            total_fixes += 1
                            card_changed = True
                            print(f"  🔧 {fname} {cid}: Added opening \" to '{s[:60]}'")
                            continue
                
                new_lines.append(line)
            
            if card_changed:
                card["text"] = '\n'.join(new_lines)
                file_changed = True
    
    if file_changed:
        with open(f, 'w') as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
            fh.write('\n')
        files_modified += 1

# JSON validation
json_errors = 0
for f in glob.glob("assets/config/journeys/**/*.json", recursive=True):
    try:
        with open(f) as fh:
            json.load(fh)
    except:
        json_errors += 1

print(f"\n{'='*60}")
print(f"Fixed {total_fixes} orphan quotes in {files_modified} files")
print(f"JSON errors: {json_errors}")
print(f"{'='*60}")

#!/usr/bin/env python3
"""Replace smart/curly quotes with straight quotes in journey JSON files."""
import os, glob

base = "assets/config/journeys"
total = 0
files_fixed = 0

replacements = {
    '\u2018': "'",  # left single
    '\u2019': "'",  # right single  
    '\u201C': '"',  # left double
    '\u201D': '"',  # right double
    '\u2013': '-',  # en dash
    '\u2014': '-',  # em dash
    '\u2026': '...', # ellipsis
}

for folder in ["singles journeys", "married journeys", "divorced journeys", "widowed journeys"]:
    path = os.path.join(base, folder)
    for fp in sorted(glob.glob(os.path.join(path, "*.json"))):
        with open(fp) as f:
            raw = f.read()
        
        new_raw = raw
        count = 0
        for old, new in replacements.items():
            c = new_raw.count(old)
            if c > 0:
                new_raw = new_raw.replace(old, new)
                count += c
        
        if count > 0:
            with open(fp, 'w') as f:
                f.write(new_raw)
            total += count
            files_fixed += 1
            print(f"  {os.path.basename(fp)}: {count} replacements")

print(f"\nDone: {total} smart chars replaced across {files_fixed} files")

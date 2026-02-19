#!/usr/bin/env python3
"""Count issues per file to understand distribution."""
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

with open(MAP_FILE) as f:
    FILE_MAP = json.load(f)
ACTIVE_FILES = set(FILE_MAP.values())

def get_all_active_files():
    files = []
    for folder in FOLDERS.values():
        if not folder.exists(): continue
        for fp in sorted(folder.glob("*.json")):
            if fp.name in ACTIVE_FILES:
                files.append((fp, fp.name))
    return files

def count_issues(text):
    """Quick count of specific issue types in text."""
    issues = {}
    
    # Unpaired bold
    odd_bold = 0
    for line in text.split("\n"):
        if line.count("**") % 2 != 0:
            odd_bold += 1
    if odd_bold: issues["UNPAIRED_BOLD"] = odd_bold
    
    # Malformed red (extra pipe)
    malformed = len(re.findall(r'\{red\|[^}]*\|[^}]*\}', text))
    if malformed: issues["MALFORMED_RED"] = malformed
    
    # Orphan quotes
    orphans = sum(1 for line in text.split("\n") if line.strip() in ['"', '"', '"'])
    if orphans: issues["ORPHAN_QUOTE"] = orphans
    
    # Words together
    together = len(re.findall(r'[a-z]\.[A-Z]', text))
    if together: issues["WORDS_TOGETHER"] = together
    
    # Unclosed {red| ... }) pattern  
    broken_red_paren = len(re.findall(r'\}\)', text))
    if broken_red_paren: issues["BROKEN_RED_PAREN"] = broken_red_paren
    
    # Inline list items
    inline_bullets = 0
    for line in text.split("\n"):
        if len(re.findall(r'[•\-\*]\s', line)) >= 2 and len(line) > 40:
            inline_bullets += 1
    if inline_bullets: issues["INLINE_BULLETS"] = inline_bullets
    
    return issues

def main():
    files = get_all_active_files()
    
    file_counts = []
    
    for filepath, filename in files:
        with open(filepath) as f:
            data = json.load(f)
        
        all_text = ""
        cards = []
        for act in data.get("activities", []):
            for card in act.get("cards", []):
                cards.append(card)
        for mission in data.get("missions", []):
            for card in mission.get("cards", []):
                cards.append(card)
        
        file_issues = {}
        for card in cards:
            for key in ["text", "prompt", "reflection"]:
                if key in card and card[key]:
                    ci = count_issues(card[key])
                    for k, v in ci.items():
                        file_issues[k] = file_issues.get(k, 0) + v
        
        total = sum(file_issues.values())
        if total > 0:
            file_counts.append((filename, total, file_issues))
    
    file_counts.sort(key=lambda x: -x[1])
    
    print(f"Files with issues: {len(file_counts)}/65\n")
    for fname, total, issues in file_counts:
        issue_str = ", ".join(f"{k}:{v}" for k, v in sorted(issues.items(), key=lambda x: -x[1]))
        print(f"  {total:4d} | {fname}")
        print(f"       | {issue_str}")

if __name__ == "__main__":
    main()

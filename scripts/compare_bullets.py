#!/usr/bin/env python3
"""
Compare git HEAD version vs current version for bullet/number counts.
Shows if we LOST bullets or numbers.
"""
import json, re, subprocess
from pathlib import Path

BASE = Path("assets/config/journeys")
MAP = json.load(open("assets/config/journey_id_filename_map.json"))
ACTIVE = set(MAP.values())

def count_items(text):
    bullets = 0
    dashes = 0
    numbered = 0
    for line in text.split("\n"):
        s = line.strip()
        if s.startswith("• "): bullets += 1
        elif s.startswith("- "): dashes += 1
        elif re.match(r"^\d+\.\s", s): numbered += 1
    return bullets, dashes, numbered

def get_git_content(filepath):
    """Get file content from git HEAD."""
    try:
        result = subprocess.run(
            ["git", "show", f"HEAD:{filepath}"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return result.stdout
    except:
        pass
    return None

losses = []
total_lost_bullets = 0
total_lost_numbered = 0
total_gained_bullets = 0
total_gained_numbered = 0

for folder in ["singles journeys","married journeys","divorced journeys","widowed journeys"]:
    fp = BASE / folder
    if not fp.exists(): continue
    for f in sorted(fp.glob("*.json")):
        if f.name not in ACTIVE: continue
        
        # Current version
        with open(f) as fh: current_data = json.load(fh)
        
        # Git version
        rel_path = str(f)
        git_content = get_git_content(rel_path)
        if not git_content: continue
        try:
            git_data = json.loads(git_content)
        except:
            continue
        
        # Collect all text from both
        def get_all_text(data):
            texts = []
            cards = []
            for act in data.get("activities",[]): cards.extend(act.get("cards",[]))
            for mis in data.get("missions",[]): cards.extend(mis.get("cards",[]))
            for card in cards:
                cid = card.get("cardId", card.get("id",""))
                for fld in ["text","prompt","reflection"]:
                    t = card.get(fld,"")
                    if t: texts.append((cid, fld, t))
            return texts
        
        git_texts = get_all_text(git_data)
        cur_texts = get_all_text(current_data)
        
        # Build maps by cardId+field
        git_map = {(cid, fld): text for cid, fld, text in git_texts}
        cur_map = {(cid, fld): text for cid, fld, text in cur_texts}
        
        for key in git_map:
            if key not in cur_map: continue
            git_b, git_d, git_n = count_items(git_map[key])
            cur_b, cur_d, cur_n = count_items(cur_map[key])
            
            git_total = git_b + git_d
            cur_total = cur_b + cur_d
            
            if git_total > cur_total:
                lost = git_total - cur_total
                total_lost_bullets += lost
                losses.append((f.name, key[0], key[1], f"Lost {lost} bullets (was {git_total}, now {cur_total})"))
            elif cur_total > git_total:
                total_gained_bullets += (cur_total - git_total)
            
            if git_n > cur_n:
                lost = git_n - cur_n
                total_lost_numbered += lost
                losses.append((f.name, key[0], key[1], f"Lost {lost} numbered (was {git_n}, now {cur_n})"))
            elif cur_n > git_n:
                total_gained_numbered += (cur_n - git_n)

print(f"BULLET/NUMBER CHANGES vs git HEAD:")
print(f"  Lost bullets: {total_lost_bullets}")
print(f"  Gained bullets: {total_gained_bullets}")
print(f"  Lost numbered: {total_lost_numbered}")
print(f"  Gained numbered: {total_gained_numbered}")
print(f"\nDETAILS ({len(losses)} cards with losses):")
for fname, cid, fld, desc in losses[:50]:
    print(f"  {fname} | {cid}/{fld}: {desc}")

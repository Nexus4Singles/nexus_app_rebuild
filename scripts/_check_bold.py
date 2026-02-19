import json, re, glob, os

base = 'assets/config/journeys'
folders = ['married journeys', 'divorced journeys', 'widowed journeys']

print("=== ODD BOLD examples ===\n")
count = 0
for folder in folders:
    for fp in sorted(glob.glob(os.path.join(base, folder, '*.json'))):
        fname = os.path.basename(fp)
        with open(fp) as f:
            data = json.load(f)
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                t = card.get('text', '')
                cid = card.get('cardId', card.get('id', '?'))
                for para in t.split('\n'):
                    if not para.strip():
                        continue
                    # Strip {red|...} first to avoid counting ** inside
                    stripped = re.sub(r'\{red\|[^}]*\}', 'REDTAG', para)
                    stars = stripped.count('**')
                    if stars % 2 != 0:
                        count += 1
                        if count <= 20:
                            print(f'{fname} {cid}: {stars} stars')
                            print(f'  PARA: {para[:150]}')
                            print(f'  STRIPPED: {stripped[:150]}')
                            print()

print(f"Total ODD_BOLD paragraphs: {count}")

print("\n\n=== BOLD_GLUED examples ===\n")
count2 = 0
for folder in folders:
    for fp in sorted(glob.glob(os.path.join(base, folder, '*.json'))):
        fname = os.path.basename(fp)
        with open(fp) as f:
            data = json.load(f)
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                t = card.get('text', '')
                cid = card.get('cardId', card.get('id', '?'))
                for m in re.finditer(r'\*\*([^*\n]{1,40})\*\*([A-Za-z])', t):
                    count2 += 1
                    if count2 <= 20:
                        ctx = t[max(0,m.start()-20):m.end()+30]
                        print(f'{fname} {cid}: ...{ctx}...')
                        print()

print(f"Total BOLD_GLUED: {count2}")

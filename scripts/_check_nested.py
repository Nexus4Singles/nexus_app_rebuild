import json, re, glob, os

base = 'assets/config/journeys'
folders = ['married journeys', 'divorced journeys', 'widowed journeys']

for folder in folders:
    for fp in sorted(glob.glob(os.path.join(base, folder, '*.json'))):
        fname = os.path.basename(fp)
        with open(fp) as f:
            data = json.load(f)
        for act in data.get('activities', []):
            for card in act.get('cards', []):
                t = card.get('text', '')
                cid = card.get('cardId', card.get('id', '?'))
                for m in re.finditer(r'\{red\|[^}]*\{red\|', t):
                    start = max(0, m.start() - 20)
                    end = min(len(t), m.end() + 60)
                    context = t[start:end].replace('\n', '\\n')
                    print(f'{fname} {cid}: ...{context}...')
                    print()

import json
import glob
from collections import defaultdict

files = glob.glob("/Users/aybaj/Documents/nexus_app_v2/assets/config/journeys/**/*.json", recursive=True)

card_types = defaultdict(int)
all_card_keys = set()

for file in files:
    with open(file) as f:
        data = json.load(f)
    
    if 'activities' in data:
        for activity in data['activities']:
            if 'cards' in activity:
                for card in activity['cards']:
                    if 'cardType' in card:
                        card_types[str(card['cardType'])] += 1
                    all_card_keys.update(card.keys())

print("Card types found:")
for ct, count in sorted(card_types.items()):
    print(f"  {ct}: {count}")

print(f"\nAll card keys: {sorted(all_card_keys)}")

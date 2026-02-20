import json
import glob

files = glob.glob("/Users/aybaj/Documents/nexus_app_v2/assets/config/journeys/**/*.json", recursive=True)

if files:
    sample = files[0]
    with open(sample) as f:
        data = json.load(f)
    
    if 'activities' in data and data['activities']:
        activity = data['activities'][0]
        print("First activity keys:", list(activity.keys()))
        print(f"\nTitle: {activity.get('title')}")
        print(f"Activity type: {activity.get('activityType')}")
        
        if 'cards' in activity:
            cards = activity['cards']
            print(f"\nCards in this activity: {len(cards)}")
            if cards:
                for i, card in enumerate(cards[:3]):
                    print(f"\nCard {i}:")
                    print(f"  Keys: {list(card.keys())}")
                    print(f"  Type: {card.get('type')}")
                    print(f"  Title: {card.get('title', 'N/A')[:50]}")
                    if 'text' in card:
                        print(f"  Text length: {len(card.get('text', ''))}")

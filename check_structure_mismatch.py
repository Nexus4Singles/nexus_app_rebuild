import json

# Check the actual structure of a journey file
with open('assets/config/journeys/singles journeys/singles_journey_01_identity_self_worth.json') as f:
    data = json.load(f)

print("===== JSON FILE STRUCTURE =====")
print(f"\nTop level keys: {list(data.keys())}")
print(f"\nHas 'activities' field: {'activities' in data}")
print(f"Has 'missions' field: {'missions' in data}")

if 'activities' in data:
    print(f"\nActivities count: {len(data['activities'])}")
    act = data['activities'][0]
    print(f"\nFirst activity keys: {list(act.keys())}")
    print(f"Activity has {len(act.get('cards', []))} cards")
    
    # Look at first card
    card = act['cards'][0]
    print(f"\nFirst card keys: {list(card.keys())}")
    print(f"  - cardType: {card.get('cardType')}")
    print(f"  - Has 'type': {'type' in card}")
    print(f"  - Has 'prompts' (plural): {'prompts' in card}")
    print(f"  - Has 'prompt' (singular): {'prompt' in card}")
    print(f"  - Has 'reflection': {'reflection' in card}")
    print(f"  - Has 'text': {'text' in card}")
    print(f"  - Has 'icon': {'icon' in card}")
    print(f"  - Has 'options': {'options' in card}")

print("\n\n===== APP EXPECTS (from Dart model) =====")
print("The app's MissionCardV1 model expects:")
print("  - 'type' field (defaults to 'instruction_card')")
print("  - 'prompt' field (singular STRING for choice cards)")
print("  - 'options' field (LIST of strings for choice cards)")
print("  - 'icon' field (STRING)")
print("  - 'text' field (STRING)")
print("  - 'bullets' field (LIST of strings)")
print("  - 'flavor' field (optional STRING)")

print("\n\n===== STRUCTURE MISMATCH =====")
print("❌ JSON has 'cardType', app expects 'type'")
print("❌ JSON has 'prompts' array, app expects 'prompt' string")
print("❌ JSON has 'reflection' field, app doesn't use it")
print("❌ JSON cards don't have 'icon' field")
print("❌ JSON cards don't have 'options' field")
print("\nThis means: The JSON files are NOT being loaded by the app!")

import json

# Analyze available content in journey JSONs
with open('assets/config/journeys/singles journeys/singles_journey_01_identity_self_worth.json') as f:
    data = json.load(f)

print("="*80)
print("CONTENT ANALYSIS: What's in JSON vs What's Being Rendered")
print("="*80)

print("\n📊 TEACHING CARD EXAMPLE:")
acts = [a for a in data['activities'] if a.get('cards')]
teach_cards = [c for c in acts[0]['cards'] if c.get('cardType') == 'teaching']
if teach_cards:
    card = teach_cards[0]
    print(f"\nFields available:")
    for key in card.keys():
        val = card[key]
        if isinstance(val, str):
            val_preview = val[:50] if len(val) > 50 else val
        else:
            val_preview = f"({len(val)} items)" if isinstance(val, list) else str(type(val).__name__)
        print(f"  • {key}: {val_preview}")

print("\n\n❓ QUESTION CARD EXAMPLE:")
quest_cards = [c for c in acts[0]['cards'] if c.get('cardType') == 'question']
if quest_cards:
    card = quest_cards[0]
    print(f"\nFields available:")
    for key in card.keys():
        val = card[key]
        if isinstance(val, str):
            val_preview = val[:50] if len(val) > 50 else val
        else:
            val_preview = f"({len(val)} items)" if isinstance(val, list) else str(type(val).__name__)
        print(f"  • {key}: {val_preview}")
    
    print(f"\nPrompts available ({len(card.get('prompts', []))} total):")
    for i, p in enumerate(card.get('prompts', [])[:3]):
        print(f"  {i+1}. {p[:60]}")
    if len(card.get('prompts', [])) > 3:
        print(f"  ... and {len(card.get('prompts', [])) - 3} more")

print("\n\n🔄 REFLECTION CARD EXAMPLE:")
refl_cards = [c for c in acts[0]['cards'] if c.get('cardType') == 'reflection']
if refl_cards:
    card = refl_cards[0]
    print(f"\nFields available:")
    for key in card.keys():
        val = card[key]
        if isinstance(val, str):
            val_preview = val[:50] if len(val) > 50 else val
        else:
            val_preview = f"({len(val)} items)" if isinstance(val, list) else str(type(val).__name__)
        print(f"  • {key}: {val_preview}")
        
    print(f"\nReflection prompt: {card.get('reflection', '')[:100]}")
    print(f"Response type: {card.get('responseType', '')}")

print("\n\n✅ WHAT'S CURRENTLY RENDERED BY THE APP:")
print("  • Title")
print("  • Text (for teaching cards)")
print("  • Prompt (single string for choice cards)")
print("  • Options (for choice cards)")
print("  • Flavor badge")

print("\n\n❌ WHAT'S AVAILABLE BUT NOT RENDERED:")
print("  • reflection: Used for guided reflection prompts")
print("  • prompts: Array for multiple question variations")
print("  • responseType: Specifies expected user response format")
print("  • cardNumber: Sequence information")
print("  • cardId: Unique identifier")

#!/usr/bin/env python3
"""Fix remaining LONG_BOLD issues - long quoted text that should not be bold."""
import json, os, re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

FILES = {
    "singles journeys": [
        "singles_journey_01_identity_self_worth.json",
        "singles_journey_04_family_patterns.json",
        "singles_journey_06_emotional_intelligence.json",
        "singles_journey_12_financial_readiness.json",
    ],
    "married journeys": [
        "married_journey_01_communication_conflict.json",
        "married_journey_06_reigniting_sexual_desire.json",
        "married_journey_16_personal_growth.json",
    ],
    "divorced journeys": [
        "divorced_journey_05_letting_go_resentment.json",
        "divorced_journey_08_coparenting.json",
    ],
    "widowed journeys": [
        "widowed_journey_01_navigating_grief_loss.json",
        "widowed_journey_03_dealing_with_loneliness.json",
        "widowed_journey_04_rebuilding_life.json",
        "widowed_journey_07_honoring_memory.json",
        "widowed_journey_09_kids_embrace_new_commitment.json",
    ],
}


def fix_long_bolds(text):
    """Convert long bold segments (>80 chars) to appropriate formatting.
    - Scripture quotes > 80 chars: remove bold
    - Key teaching statements > 80 chars: remove bold
    - Narrative sentences > 80 chars: remove bold
    """
    def unbold(m):
        inner = m.group(1)
        if len(inner) <= 80:
            return m.group(0)
        return inner
    
    return re.sub(r'\*\*(.+?)\*\*', unbold, text, flags=re.DOTALL)


def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for card in activity.get('cards', []):
                for field in ['text', 'reflection']:
                    if field in card and card[field] and isinstance(card[field], str):
                        card[field] = fix_long_bolds(card[field])
    
    updated = json.dumps(data, ensure_ascii=False)
    if original != updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        return True
    return False


def main():
    modified = 0
    for cat, files in FILES.items():
        folder = os.path.join(JOURNEYS_DIR, cat)
        for fname in files:
            filepath = os.path.join(folder, fname)
            if not os.path.exists(filepath):
                continue
            if process_file(filepath):
                modified += 1
                print(f"  + {fname}")
            else:
                print(f"  . {fname}")
    print(f"\nDone: {modified} files modified")


if __name__ == '__main__':
    main()

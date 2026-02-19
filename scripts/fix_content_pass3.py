#!/usr/bin/env python3
"""
Fix Pass 3: Address remaining specific patterns.
1. Missing \n\n before **Label**: in lists (where no punctuation precedes)
2. Missing \n\n after **Label:** before description text
3. Stray ** after "talking." or similar (removes entire phrase bold)
4. "Lies,even" → "Lies, even" (missing space after comma)
5. "goal-orientedThe" style word boundaries
"""

import json
import os
import re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

FILES = {
    "singles journeys": [
        "singles_journey_01_identity_self_worth.json",
        "singles_journey_02_cultural_lies.json",
        "singles_journey_03_healing_past_wounds.json",
        "singles_journey_04_family_patterns.json",
        "singles_journey_05_emotional_readiness.json",
        "singles_journey_06_emotional_intelligence.json",
        "singles_journey_07_secure_confidence.json",
        "singles_journey_08_toxic_triggers.json",
        "singles_journey_09_biblical_femininity.json",
        "singles_journey_09_biblical_masculinity.json",
        "singles_journey_10_communicate_better.json",
        "singles_journey_11_healthy_boundaries.json",
        "singles_journey_12_financial_readiness.json",
        "singles_journey_13_red_flags.json",
        "singles_journey_14_compatibility.json",
        "singles_journey_15_dating_purpose.json",
        "singles_journey_16_sexual_chemistry.json",
        "singles_journey_17_faith_alignment.json",
        "singles_journey_18_purity.json",
        "singles_journey_19_choosing_spouse.json",
        "singles_journey_20_fear_commitment.json",
    ],
    "married journeys": [
        "married_journey_01_communication_conflict.json",
        "married_journey_02_harmful_conflict_patterns.json",
        "married_journey_03_restoring_friendship.json",
        "married_journey_04_emotional_physical_intimacy.json",
        "married_journey_05_keeping_romance_alive.json",
        "married_journey_06_reigniting_sexual_desire.json",
        "married_journey_07_rebuilding_trust.json",
        "married_journey_08_handling_infidelity.json",
        "married_journey_09_roles_expectations.json",
        "married_journey_10_masculinity_femininity.json",
        "married_journey_11_cultural_differences.json",
        "married_journey_12_managing_finances.json",
        "married_journey_13_parenting_united_team.json",
        "married_journey_14_infertility.json",
        "married_journey_15_healthy_boundaries_extended_family.json",
        "married_journey_16_personal_growth.json",
        "married_journey_17_faith_spiritual_unity.json",
        "married_journey_18_shared_purpose_vision.json",
    ],
    "divorced journeys": [
        "divorced_journey_01_understanding_what_went_wrong.json",
        "divorced_journey_02_processing_pain.json",
        "divorced_journey_03_healing_restoration.json",
        "divorced_journey_04_identity_selfworth.json",
        "divorced_journey_05_letting_go_resentment.json",
        "divorced_journey_06_faith_church_community.json",
        "divorced_journey_07_financial_recovery.json",
        "divorced_journey_08_coparenting.json",
        "divorced_journey_09_anniversaries_occasions.json",
        "divorced_journey_10_ex_moves_on.json",
        "divorced_journey_11_developing_trust.json",
        "divorced_journey_12_toxic_patterns.json",
        "divorced_journey_13_emotional_readiness.json",
        "divorced_journey_14_discerning_healthy_love.json",
        "divorced_journey_15_dating_again.json",
        "divorced_journey_16_preparing_new_covenant.json",
    ],
    "widowed journeys": [
        "widowed_journey_01_navigating_grief_loss.json",
        "widowed_journey_02_staying_present_for_kids.json",
        "widowed_journey_03_dealing_with_loneliness.json",
        "widowed_journey_04_rebuilding_life.json",
        "widowed_journey_05_holidays_anniversaries.json",
        "widowed_journey_06_rediscovering_identity.json",
        "widowed_journey_07_honoring_memory.json",
        "widowed_journey_08_opening_heart_new_love.json",
        "widowed_journey_09_kids_embrace_new_commitment.json",
        "widowed_journey_10_preparing_new_covenant.json",
    ],
}

changes = []


def fix_text(text, title, fname):
    if not text or not isinstance(text, str):
        return text
    original = text

    # Fix 1: Add \n\n before **Label** or **Label: in a list context
    # Pattern: "word **Label" where word is preceded by text (not \n)
    # "trust **Respect**:" → "trust\n\n**Respect**:"
    text = re.sub(
        r'([a-z]) (\*\*[A-Z][^*\n]{1,50}\*\*:)',
        r'\1\n\n\2',
        text
    )
    # Same but for **Label: (without closing **)
    text = re.sub(
        r'([a-z]) (\*\*[A-Z][^*\n]{1,50}:)',
        r'\1\n\n\2',
        text
    )

    # Fix 2: Add \n\n after **Label:** when followed directly by text
    # "everything:**Career" → "everything:**\n\nCareer"
    text = re.sub(
        r'(\*\*:?\*?\*?)\s*([A-Z][a-z])',
        lambda m: m.group(0) if '\n' in m.group(0) else m.group(1) + '\n\n' + m.group(2),
        text
    )

    # Fix 3: Fix "word.** " stray bold that makes whole paragraphs bold
    # **External processors** think by talking.** → **External processors** think by talking.
    # Pattern: **Label** description.\n\n → remove the extra **
    # Actually: "talking.**\n\n" → "talking.\n\n" (remove stray **)
    text = re.sub(
        r'([a-z])\.(\*\*)\n\n',
        r'\1.\n\n',
        text
    )

    # Fix 4: Fix missing space after comma in labels
    text = re.sub(r',([a-z])', r', \1', text)

    # Fix 5: Fix word-boundary issues (lowercase touching uppercase after hyphen or directly)
    # "goal-orientedThe" → "goal-oriented\n\nThe"
    # "resolvedFor" → "resolved\n\nFor"
    text = re.sub(
        r'([a-z])-([a-z]+)([A-Z][a-z]{3,})',
        r'\1-\2\n\n\3',
        text
    )

    # Fix 6: Fix "minutes?"Step" type issues (punctuation touching uppercase)
    text = re.sub(
        r'([?!"])([A-Z][a-z]{2,})',
        lambda m: m.group(1) + '\n\n' + m.group(2) if m.group(2) not in ['I', 'In'] else m.group(0),
        text
    )

    # Fix 7: In sequences of "Label: description Label2: description"
    # where labels are NOT bold, add \n between them
    # "benefits family Marriage boundaries:" → "benefits family\n\nMarriage boundaries:"
    text = re.sub(
        r'([a-z]) ([A-Z][a-z]+(?:\s+[a-z]+)*:) ',
        lambda m: m.group(1) + '\n\n' + m.group(2) + ' ' 
            if len(m.group(2)) < 40 and ':' in m.group(2)
            else m.group(0),
        text
    )

    # Fix 8: Fix unclosed bold on labels like "**Present unity to kids: Children"
    # → "**Present unity to kids:** Children"
    text = re.sub(
        r'\*\*([^*\n]{3,50}): ([A-Z])',
        lambda m: '**' + m.group(1) + ':** ' + m.group(2),
        text
    )
    
    # Fix 9: Add bold to non-bold labels when surrounded by bold labels
    # If text has 3+ bold labels (**Label:**), and a non-bold label on its own line,
    # make it bold too
    bold_count = len(re.findall(r'\*\*[^*]+\*\*:', text))
    if bold_count >= 2:
        # Find non-bold labels after \n\n: "Decide together:" → "**Decide together:**"
        text = re.sub(
            r'(?<=\n\n)([A-Z][a-z][\w\s]{2,35}): ',
            r'**\1:** ',
            text
        )
        # Also at start of text
        text = re.sub(
            r'^([A-Z][a-z][\w\s]{2,35}): ',
            r'**\1:** ',
            text
        )

    # Cleanup: remove triple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()

    if text != original:
        changes.append(f"  [{fname}] {title}")
    return text


def process_file(filepath, fname):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    original = json.dumps(data, ensure_ascii=False)
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for i, card in enumerate(activity.get('cards', [])):
                title = card.get('title', card.get('cardId', card.get('id', '?')))
                for field in ['text', 'reflection', 'prompt']:
                    if field in card and card[field] and isinstance(card[field], str):
                        card[field] = fix_text(card[field], title, fname)
                if 'bullets' in card and card['bullets']:
                    card['bullets'] = [
                        fix_text(b, title, fname) if isinstance(b, str) else b
                        for b in card['bullets']
                    ]
    updated = json.dumps(data, ensure_ascii=False)
    if original != updated:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        return True
    return False


def main():
    total = 0
    modified = 0
    for category, files in FILES.items():
        folder = os.path.join(JOURNEYS_DIR, category)
        for fname in files:
            filepath = os.path.join(folder, fname)
            if not os.path.exists(filepath):
                continue
            total += 1
            changes.clear()
            try:
                if process_file(filepath, fname):
                    modified += 1
                    print(f"+ {fname}")
                    for c in changes:
                        print(c)
                else:
                    print(f". {fname}")
            except Exception as e:
                print(f"! {fname}: {e}")
                import traceback
                traceback.print_exc()
    print(f"\n=== Done: {modified}/{total} modified ===")


if __name__ == '__main__':
    main()

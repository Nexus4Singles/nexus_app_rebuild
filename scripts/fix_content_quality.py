#!/usr/bin/env python3
"""
Content quality pass: Improve text organization and readability.
Focuses on:
1. Adding paragraph breaks between sections/topics within a card
2. Ensuring labeled items (Key: description) have proper line breaks
3. Converting numbered lists to proper format
4. Ensuring scripture quotes are properly separated from surrounding text
5. Adding line breaks before/after subheadings
6. Moving inline list items to bullets array where appropriate
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


def improve_text_structure(text):
    """Improve text organization with proper breaks and structure."""
    if not text or not isinstance(text, str):
        return text
    
    original = text
    
    # 1. Ensure bold labels followed by text get a proper line break
    # Pattern: "sentence.**Label:** description" -> "sentence.\n\n**Label:** description"
    text = re.sub(
        r'([.!?"\u201d])\s*(\*\*[A-Z][^*]{2,50}\*\*[:\s])',
        r'\1\n\n\2',
        text
    )
    
    # 2. Also for bold labels without ** ending in colon: "sentence. Label: desc"
    # But be careful not to break normal sentences
    
    # 3. Ensure numbered items get line breaks
    # Pattern: "text. 1. Item" or "text.1. Item" -> "text.\n\n1. Item"
    text = re.sub(
        r'([.!?])\s*(\d+\.\s+[A-Z])',
        r'\1\n\n\2',
        text
    )
    
    # 4. Ensure "Step N:" patterns get line breaks
    text = re.sub(
        r'([.!?"\u201d])\s*(\*?\*?Step\s+\d+)',
        r'\1\n\n\2',
        text
    )
    
    # 5. Add line break after long quote followed by a reference, before next paragraph
    # Pattern: "...quote text." (Reference) "Next paragraph" 
    text = re.sub(
        r'(\{red\|[^}]+\})\s*([A-Z][a-z])',
        r'\1\n\n\2',
        text
    )
    
    # 6. Ensure there's a break before bold-only lines that serve as subheadings
    # Pattern: "sentence.\n**Subheading**\n" - make sure there's double newline before
    text = re.sub(
        r'([.!?])\n(\*\*[^*]+\*\*)\n',
        r'\1\n\n\2\n',
        text
    )
    
    # 7. Fix sentences that run together with no space after period
    # Pattern: "word.Next" -> "word. Next" (but not for abbreviations like "vs." or "Dr.")
    text = re.sub(
        r'([a-z])\.\s*([A-Z][a-z]{2,})',
        r'\1. \2',
        text
    )
    
    # 8. Fix places where commas are missing before key conjunctions after sentences
    # Pattern: "sentence,something" -> "sentence, something"  
    text = re.sub(r',([A-Za-z])', r', \1', text)
    
    # Clean up: normalize multiple newlines
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = re.sub(r'  +', ' ', text)
    text = text.strip()
    
    return text


def extract_inline_bullets(text):
    """
    Check if text contains inline list items that should be bullets.
    Returns (cleaned_text, bullets_list) or (text, None) if no bullets found.
    """
    # Look for patterns like:
    # • Item 1\n• Item 2 (already has bullet chars)
    # or numbered: 1. Item\n2. Item
    
    lines = text.split('\n')
    bullet_lines = []
    text_lines = []
    in_bullets = False
    
    for line in lines:
        stripped = line.strip()
        # Check if this is a bullet-like line
        if re.match(r'^[•\-\*]\s+', stripped):
            in_bullets = True
            bullet_lines.append(re.sub(r'^[•\-\*]\s+', '', stripped))
        elif in_bullets and stripped and not stripped.endswith(':'):
            # Continuation of bullet section
            bullet_lines.append(stripped)
        else:
            in_bullets = False
            text_lines.append(line)
    
    if bullet_lines and len(bullet_lines) >= 2:
        return '\n'.join(text_lines).strip(), bullet_lines
    
    return text, None


def process_card(card, category):
    """Process a single card for content quality."""
    card_type = card.get('cardType', card.get('type', 'teaching')).lower()
    
    if 'text' in card and card['text'] and isinstance(card['text'], str):
        improved = improve_text_structure(card['text'])
        
        # Try to extract inline bullets only if card doesn't already have bullets
        if not card.get('bullets'):
            cleaned, bullets = extract_inline_bullets(improved)
            if bullets:
                card['text'] = cleaned
                card['bullets'] = bullets
            else:
                card['text'] = improved
        else:
            card['text'] = improved
        
        # Also improve existing bullets
        if card.get('bullets'):
            card['bullets'] = [
                improve_text_structure(b) for b in card['bullets']
                if b and isinstance(b, str)
            ]
    
    if 'reflection' in card and card['reflection'] and isinstance(card['reflection'], str):
        card['reflection'] = improve_text_structure(card['reflection'])
    
    return card


def process_file(filepath, category):
    """Process a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for i, card in enumerate(activity.get('cards', [])):
                activity['cards'][i] = process_card(card, category)
    
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
        print(f"\n=== {category} ===")
        
        for fname in files:
            filepath = os.path.join(folder, fname)
            if not os.path.exists(filepath):
                continue
            total += 1
            try:
                if process_file(filepath, category):
                    modified += 1
                    print(f"  + {fname}")
                else:
                    print(f"  . {fname}")
            except Exception as e:
                print(f"  ! {fname}: {e}")
                import traceback
                traceback.print_exc()
    
    print(f"\n=== Done: {modified}/{total} modified ===")


if __name__ == '__main__':
    main()

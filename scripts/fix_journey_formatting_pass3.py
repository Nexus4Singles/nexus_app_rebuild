#!/usr/bin/env python3
"""
Third pass: Aggressively fix remaining broken {red|} and ** in all files.
Strategy: For any text with broken {red|} (opens != closes), strip ALL {red|}
tags and re-add them only around valid scripture references.
Same for odd ** counts - fix the orphaned markers.
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

BIBLE_BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
    "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalm", "Psalms",
    "Proverbs", "Ecclesiastes", "Song of Solomon", "Song of Songs",
    "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
    "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
    "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon",
    "Hebrews", "James", "1 Peter", "2 Peter",
    "1 John", "2 John", "3 John", "Jude", "Revelation",
]
SORTED_BOOKS = sorted(BIBLE_BOOKS, key=len, reverse=True)
BOOK_RE = "|".join(re.escape(b) for b in SORTED_BOOKS)
SCRIPTURE_RE = re.compile(r'\b(' + BOOK_RE + r')\s+(\d+:\d+(?:\s*-\s*\d+(?::\d+)?)?)\b')


def count_valid_red_pairs(text):
    """Count properly paired {red|...} tags."""
    count = 0
    i = 0
    while i < len(text):
        if text[i:i+5] == '{red|':
            # Find matching }
            depth = 1
            j = i + 5
            while j < len(text) and depth > 0:
                if text[j:j+5] == '{red|':
                    depth += 1
                    j += 5
                elif text[j] == '}':
                    depth -= 1
                    j += 1
                else:
                    j += 1
            if depth == 0:
                count += 1
            i = j
        else:
            i += 1
    return count


def has_broken_red(text):
    """Check if text has broken {red|} tags."""
    opens = text.count('{red|')
    if opens == 0:
        return False
    
    # Try to properly match each {red|...}
    matched = count_valid_red_pairs(text)
    return matched != opens


def strip_all_red(text):
    """Completely strip all {red| and } patterns, keeping content."""
    # Handle {red|ref|display} -> ref (keep the reference)
    result = re.sub(r'\{red\|([^|}]+)\|[^}]*\}', r'\1', text)
    # Handle {red|text} -> text
    result = re.sub(r'\{red\|([^}]*)\}', r'\1', result)
    # Handle orphaned {red| without matching }
    result = result.replace('{red|', '')
    # Handle orphaned }
    # Only remove } that are likely tag closers (after text that was preceded by {red|)
    # Be careful not to remove } that are part of the content
    return result


def add_scripture_red_tags(text):
    """Add {red|...} around bare scripture references."""
    matches = list(SCRIPTURE_RE.finditer(text))
    if not matches:
        return text
    
    result = text
    for m in reversed(matches):
        start = m.start()
        end = m.end()
        ref = m.group(0)
        # Check if already inside a {red| tag
        before = result[max(0, start-10):start]
        if '{red|' in before:
            continue
        result = result[:start] + '{red|' + ref + '}' + result[end:]
    
    return result


def fix_odd_bold(text):
    """Fix text with odd number of ** markers."""
    count = text.count('**')
    if count == 0 or count % 2 == 0:
        return text
    
    # Strategy: find each ** and try to pair them
    # First, find all ** positions
    positions = []
    idx = 0
    while True:
        pos = text.find('**', idx)
        if pos == -1:
            break
        positions.append(pos)
        idx = pos + 2
    
    if len(positions) % 2 == 0:
        return text  # Should not happen but safety check
    
    # Heuristic: the orphan ** is likely:
    # 1. At the very end of text
    # 2. After a period/end of sentence
    # 3. Before or after a {red| tag
    
    # Try removing the last **
    last_pos = positions[-1]
    after_last = text[last_pos+2:].strip()
    before_last = text[:last_pos].rstrip()
    
    # If last ** is at the end or followed by nothing meaningful
    if not after_last or after_last.startswith(('\n', '.', ')', ',')):
        result = text[:last_pos] + text[last_pos+2:]
        if result.count('**') % 2 == 0:
            return result
    
    # If last ** is after a period (sentence-ending orphan)
    if before_last.endswith(('.', '!', '?', '"', "'", '\u201d')):
        result = text[:last_pos] + text[last_pos+2:]
        if result.count('**') % 2 == 0:
            return result
    
    # Try removing the first **
    first_pos = positions[0]
    result = text[:first_pos] + text[first_pos+2:]
    if result.count('**') % 2 == 0:
        return result
    
    # Last resort: just remove the last one
    result = text[:last_pos] + text[last_pos+2:]
    return result


def fix_malformed_markers(text):
    """Fix {red) and similar broken patterns."""
    text = text.replace('({red)', '')
    text = text.replace('{red)', '')
    text = text.replace('|**}', '}')
    # Fix }|Commit... pattern (broken pipe/brace order)
    text = re.sub(r'\}\|([A-Z])', r'} \1', text)
    return text


def fix_text(text, card_type):
    """Apply all third-pass fixes."""
    if not text or not isinstance(text, str):
        return text
    
    original = text
    
    # Step 1: Fix malformed markers
    text = fix_malformed_markers(text)
    
    # Step 2: If {red|} tags are broken, nuke them all and re-add cleanly
    if has_broken_red(text):
        text = strip_all_red(text)
        # Clean up any orphaned } that might remain
        # Only remove } that seem like orphaned red-tag closers
        # (followed by ) or preceded by nothing that would be a natural })
        text = add_scripture_red_tags(text)
    
    # Step 3: Fix odd bold count
    text = fix_odd_bold(text)
    
    # Step 4: Clean up whitespace
    text = re.sub(r'  +', ' ', text)
    text = re.sub(r' +\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()
    
    return text


def process_file(filepath, category):
    """Process a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    activities_key = None
    for key in ['activities', 'missions']:
        if key in data and isinstance(data[key], list):
            activities_key = key
            break
    
    if not activities_key:
        return False
    
    for activity in data[activities_key]:
        for card in activity.get('cards', []):
            card_type = card.get('cardType', card.get('type', 'teaching')).lower()
            
            for field in ['text', 'reflection']:
                if field in card and card[field] and isinstance(card[field], str):
                    card[field] = fix_text(card[field], card_type)
    
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

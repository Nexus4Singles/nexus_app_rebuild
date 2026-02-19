#!/usr/bin/env python3
"""
Second pass: Fix remaining formatting issues in journey JSON files.
Focuses on:
1. Entire card text wrapped in {red|...} (WHOLE_RED)
2. Broken {red| tags with mismatched counts (BROKEN_RED)
3. Bold markers inside {red|} display text (BOLD_IN_RED)
4. Malformed markers like {red) or |**}
5. Long bold quoted sentences that should be italic or normal
6. Fragmented {red|} across sentence boundaries
"""

import json
import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

# Only process active files
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

# Bible book patterns for re-wrapping scripture refs after stripping {red|}
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
BIBLE_BOOKS_SORTED = sorted(BIBLE_BOOKS, key=len, reverse=True)
BIBLE_BOOK_RE = "|".join(re.escape(b) for b in BIBLE_BOOKS_SORTED)
SCRIPTURE_REF_PATTERN = re.compile(
    r'\b(' + BIBLE_BOOK_RE + r')\s+(\d+:\d+(?:\s*-\s*\d+(?::\d+)?)?)\b'
)


def strip_all_red_tags(text):
    """Remove all {red|...} formatting, keeping the display text or reference."""
    # First handle {red|ref|display} -> display text
    result = re.sub(r'\{red\|[^|]+\|([^}]*)\}', r'\1', text)
    # Then handle {red|text} -> text
    result = re.sub(r'\{red\|([^}]*)\}', r'\1', result)
    return result


def wrap_scripture_refs_in_red(text):
    """Find bare scripture references and wrap in {red|...}."""
    def replace_ref(m):
        ref = m.group(0)
        # Check if already inside a {red| tag
        start = m.start()
        before = text[max(0, start-10):start]
        if '{red|' in before:
            return ref
        return '{red|' + ref + '}'
    
    result = text
    # Process from end to start to maintain positions
    matches = list(SCRIPTURE_REF_PATTERN.finditer(text))
    for m in reversed(matches):
        ref = m.group(0)
        start = m.start()
        # Check if already inside a {red| tag
        before = result[max(0, start-10):start]
        if '{red|' in before:
            continue
        result = result[:m.start()] + '{red|' + ref + '}' + result[m.end():]
    
    return result


def fix_whole_red_text(text, card_type):
    """
    Remove {red|} wrapping from entire card text.
    Question/reflection card text should be plain.
    Teaching/action cards should only have {red|} on scripture references.
    """
    stripped = text.strip()
    
    # Case 1: Entire text is one {red|...} block
    if stripped.startswith('{red|'):
        # Find the matching closing }
        depth = 0
        end_pos = -1
        i = 0
        while i < len(stripped):
            if stripped[i:i+5] == '{red|':
                depth += 1
                i += 5
            elif stripped[i] == '}' and depth > 0:
                depth -= 1
                if depth == 0:
                    end_pos = i
                    break
                i += 1
            else:
                i += 1
        
        # If the entire text is wrapped in {red|...}
        if end_pos == len(stripped) - 1:
            inner = stripped[5:end_pos]
            # Check if this is a pipe-separated reference {red|ref|text}
            pipe_pos = inner.find('|')
            if pipe_pos > 0 and pipe_pos < 50:
                # This might be a legitimate {red|ref|display text} - check if ref looks like scripture
                ref_part = inner[:pipe_pos]
                if SCRIPTURE_REF_PATTERN.search(ref_part) and len(inner) < 200:
                    return text  # Legitimate scripture reference
            
            # Strip the {red|} wrapper
            result = inner
            # Re-wrap any scripture references
            result = wrap_scripture_refs_in_red(result)
            return result
    
    # Case 2: Text has multiple fragmented {red|...} blocks covering most/all content
    # Count how much of the text is inside {red|} vs outside
    red_content_len = 0
    for m in re.finditer(r'\{red\|([^}]*)\}', stripped):
        red_content_len += len(m.group(1))
    
    plain_text = strip_all_red_tags(stripped)
    
    if len(plain_text) > 0 and red_content_len / max(len(plain_text), 1) > 0.7:
        # More than 70% of content is in {red|} - strip it all and re-add scripture refs
        result = strip_all_red_tags(stripped)
        result = wrap_scripture_refs_in_red(result)
        return result
    
    return text


def fix_broken_red_display(text):
    """
    Fix {red|Book:XX** stuff} where ** leaked into display text,
    and {red|Genesis 1:** 27}) patterns.
    """
    # Pattern: {red|Book Ch:**Verse} -> {red|Book Ch:Verse}
    text = re.sub(
        r'\{red\|([A-Za-z0-9 ]+\s+\d+):\*\*\s*(\d+(?:-\d+)?)\}',
        lambda m: '{red|' + m.group(1) + ':' + m.group(2) + '}',
        text
    )
    
    # Pattern: {red|ref|**} -> {red|ref}
    text = re.sub(r'\{red\|([^|]+)\|\*\*\}', r'{red|\1}', text)
    
    # Pattern: {red|ref|** display with bold **} - clean bold from display
    def clean_bold_display(m):
        ref = m.group(1)
        display = m.group(2).replace('**', '').strip()
        if display:
            return '{red|' + ref + '|' + display + '}'
        return '{red|' + ref + '}'
    text = re.sub(r'\{red\|([^|]+)\|([^}]*\*\*[^}]*)\}', clean_bold_display, text)
    
    return text


def fix_malformed_red(text):
    """Fix malformed {red) and similar patterns."""
    # {red) -> remove (completely malformed)
    text = text.replace('({red)', '')
    text = text.replace('{red)', '')
    
    # Stray }) that don't have matching {red|
    # Fix: (BookName Ch:V}) -> ({red|BookName Ch:V})
    def fix_stray_close(m):
        before_paren = m.group(1)
        ref = m.group(2)
        verse = m.group(3)
        return before_paren + '({red|' + ref + ' ' + verse + '})'
    
    text = re.sub(
        r'(\s*)\((' + BIBLE_BOOK_RE + r')\s+(\d+:\d+(?:-\d+)?)\}\)',
        fix_stray_close,
        text
    )
    
    # Remove |**} pattern (broken display text)
    text = text.replace('|**}', '}')
    
    return text


def fix_long_bold_quotes(text):
    """
    Convert long bold quoted text to non-bold.
    Scripture quotes should not be bold - they should be in {red|} or plain.
    Long quotes (>80 chars) in bold are likely scripture or key passages.
    """
    def unbold_long_quote(m):
        inner = m.group(1)
        if len(inner) > 80:
            # Check if it's a quoted passage (starts with quote mark)
            if inner.strip().startswith(('"', '\u201c', "'")):
                return inner  # Remove bold from long quotes
        return m.group(0)  # Keep short bolds
    
    text = re.sub(r'\*\*(.+?)\*\*', unbold_long_quote, text, flags=re.DOTALL)
    return text


def fix_double_closing_braces(text):
    """Fix }} at end of {red|} tags."""
    # {red|..}} -> {red|..}
    text = re.sub(r'(\{red\|[^}]*)\}\}', r'\1}', text)
    return text


def fix_mismatched_bold(text):
    """Try to fix odd numbers of ** markers."""
    count = text.count('**')
    if count % 2 == 0:
        return text
    
    # Common pattern: ** at end after a period: "text.**" -> "text."
    text = re.sub(r'\.\*\*"', '."', text)
    text = re.sub(r'\.\*\*(?=\s|$)', '.', text)
    
    # Leading ** without matching close
    # Check if still odd
    count = text.count('**')
    if count % 2 != 0:
        # Try removing orphan ** at end of text
        if text.rstrip().endswith('**'):
            text = text.rstrip()[:-2]
        # Or orphan ** at start
        elif text.lstrip().startswith('**'):
            text = text.lstrip()[2:]
    
    return text


def process_text(text, card_type, category):
    """Apply all second-pass fixes to a text field."""
    if not text or not isinstance(text, str):
        return text
    
    original = text
    
    # Fix malformed patterns first
    text = fix_malformed_red(text)
    text = fix_double_closing_braces(text)
    text = fix_broken_red_display(text)
    
    # Remove {red|} from entire text blocks
    text = fix_whole_red_text(text, card_type)
    
    # Fix long bold quotes
    text = fix_long_bold_quotes(text)
    
    # Fix mismatched bold markers
    text = fix_mismatched_bold(text)
    
    # Clean up whitespace
    text = re.sub(r'  +', ' ', text)
    text = re.sub(r' +\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()
    
    return text


def process_reflection(text, card_type, category):
    """Process reflection fields - these should NEVER be in {red|}."""
    if not text or not isinstance(text, str):
        return text
    
    # Strip all {red|} from reflections
    result = strip_all_red_tags(text)
    result = result.strip()
    return result


def process_card(card, category):
    """Process a single card."""
    card_type = card.get('cardType', card.get('type', 'teaching')).lower()
    
    if 'text' in card and card['text'] and isinstance(card['text'], str):
        card['text'] = process_text(card['text'], card_type, category)
    
    if 'reflection' in card and card['reflection'] and isinstance(card['reflection'], str):
        card['reflection'] = process_reflection(card['reflection'], card_type, category)
    
    return card


def process_file(filepath, category):
    """Process a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    activities_key = None
    for key in ['activities', 'missions', 'lessons', 'steps', 'modules']:
        if key in data and isinstance(data[key], list):
            activities_key = key
            break
    
    if not activities_key:
        return False
    
    for activity in data[activities_key]:
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
                print(f"  MISSING: {fname}")
                continue
            
            total += 1
            try:
                changed = process_file(filepath, category)
                if changed:
                    modified += 1
                    print(f"  + {fname}")
                else:
                    print(f"  . {fname}")
            except Exception as e:
                print(f"  ! ERROR {fname}: {e}")
                import traceback
                traceback.print_exc()
    
    print(f"\n=== Done: {modified}/{total} modified ===")


if __name__ == '__main__':
    main()

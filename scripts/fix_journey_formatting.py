#!/usr/bin/env python3
"""
Journey JSON Formatting Fixer
Systematically fixes formatting issues across all journey JSON files.

Issues addressed:
1. Excessive bolding (entire paragraphs wrapped in **...**)
2. Broken {red|} tags (missing delimiters, book numbers outside tags)
3. {red|} wrapping entire paragraphs/questions (should be plain or minimal)
4. Double parentheses around scripture refs
5. Empty {red|} tags
6. Fragmented {red|} tags
7. Wall-of-text needing line breaks between labeled items
8. Scripture references not in {red|} tags
"""

import json
import re
import os
import sys
import copy

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JOURNEYS_DIR = os.path.join(BASE_DIR, "assets", "config", "journeys")

# All active journey files grouped by category
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

# Common Bible books for scripture detection
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

# Build regex pattern for scripture detection
# Sort by length desc so "1 Corinthians" matches before "Corinthians"
BIBLE_BOOKS_SORTED = sorted(BIBLE_BOOKS, key=len, reverse=True)
BIBLE_BOOK_PATTERN = "|".join(re.escape(b) for b in BIBLE_BOOKS_SORTED)
# Match: BookName Chapter:Verse(-Verse)
SCRIPTURE_REF_RE = re.compile(
    rf'(?<!\{{red\|)(?<!\|)\b({BIBLE_BOOK_PATTERN})\s+(\d+:\d+(?:-\d+)?)\b'
)


def fix_double_parens_scripture(text):
    """Fix (({red|..})) -> ({red|..})"""
    return re.sub(r'\(\(\{red\|([^}]*)\}\)\)', r'({red|\1})', text)


def fix_empty_red_tags(text):
    """Remove empty {red|} tags"""
    text = re.sub(r'\{red\|\}', '', text)
    # Also remove {red| } with just whitespace
    text = re.sub(r'\{red\|\s*\}', '', text)
    return text


def fix_book_number_outside_red(text):
    """Fix '(1 {red|Corinthians 7:10})' -> '({red|1 Corinthians 7:10})'"""
    # Pattern: (N {red|BookName...) where N is 1, 2, or 3
    text = re.sub(
        r'\(([123])\s+\{red\|(\w)',
        r'({red|\1 \2',
        text
    )
    return text


def fix_red_with_display_text_abuse(text):
    """
    Fix {red|Verse|display text that is actually paragraph content} 
    -> {red|Verse} + the paragraph content as plain text.
    
    The {red|Book Ch:V|text} format should only have the actual scripture quote as display.
    If the display text is more than ~120 chars, it's probably paragraph content leaking in.
    Also fix cases where ** bold markers are inside display text.
    """
    def fix_red_display(m):
        full = m.group(0)
        ref = m.group(1)
        display = m.group(2)
        
        # If display text contains ** bold markers, it's broken
        if '**' in display:
            # Try to extract just the scripture quote
            # Remove bold markers and see if it's reasonable
            clean = display.replace('**', '').strip()
            if len(clean) > 150:
                # Too long - just use the reference
                return '{red|' + ref + '}'
            return '{red|' + ref + '}'
        
        # If display text is very long (>150 chars), it's paragraph content
        if len(display) > 150:
            return '{red|' + ref + '}'
        
        # If display text contains another scripture reference, it's broken
        if '{red|' in display or '(' in display:
            return '{red|' + ref + '}'
        
        return full  # Leave valid short display text alone
    
    text = re.sub(
        r'\{red\|([^|]+)\|([^}]+)\}',
        fix_red_display,
        text
    )
    return text


def fix_fragmented_red_tags(text):
    """
    Fix fragmented {red|} tags where a sentence is split:
    {red|text1}{red| text2}{red| text3} -> {red|text1 text2 text3}
    """
    # Merge adjacent {red|} tags
    while re.search(r'\}\{red\|', text):
        text = re.sub(r'\}\{red\|', '', text, count=1)
    return text


def fix_red_wrapping_entire_text(text, card_type):
    """
    Remove {red|} wrapping from entire card text.
    Questions/reflections should NOT be in {red|}.
    Teaching text should NOT be entirely in {red|}.
    """
    stripped = text.strip()
    
    # Check if the entire text is wrapped in {red|...}
    if stripped.startswith('{red|') and stripped.endswith('}'):
        # Check if this is actually the entire text (no other content outside)
        inner = stripped[5:-1]
        # Make sure we're not removing a legitimate short scripture reference
        if len(inner) > 80 or card_type in ('question', 'reflection'):
            # Check for nested pipe (display text pattern) - don't break those
            if '|' not in inner or len(inner) > 200:
                return inner
    
    # Handle case where text starts with {red| and has fragmented blocks
    if stripped.startswith('{red|'):
        # Count opening and closing
        opens = text.count('{red|')
        closes = text.count('}')
        # If significantly more content than just a reference
        if opens > 2 or len(text) > 300:
            # Remove all {red|} wrappers
            result = text.replace('{red|', '').replace('}', '')
            # But this is too aggressive - might break legitimate references
            # Instead, let's be more targeted
            pass
    
    return text


def remove_excessive_bold(text, card_type):
    """
    Remove excessive bolding from body paragraphs.
    Keep bold for:
    - Subheadings/labels (short phrases ending with :)
    - Key phrases (quoted text)
    - Short emphasis (< 60 chars)
    
    Remove bold from:
    - Full sentences (> 80 chars)
    - Entire paragraphs
    """
    lines = text.split('\n')
    result_lines = []
    
    for line in lines:
        result_lines.append(fix_line_bold(line, card_type))
    
    return '\n'.join(result_lines)


def fix_line_bold(line, card_type):
    """Fix bolding on a single line."""
    stripped = line.strip()
    if not stripped:
        return line
    
    # Find all **..** segments
    bold_segments = list(re.finditer(r'\*\*(.+?)\*\*', stripped))
    if not bold_segments:
        return line
    
    result = stripped
    replacements = []
    
    for m in bold_segments:
        inner = m.group(1)
        full = m.group(0)
        
        # KEEP bold if:
        # - It's a label/subheading (ends with :)
        if inner.strip().endswith(':'):
            continue
        # - It's a short keyword or phrase (<= 50 chars, no period at end)
        if len(inner) <= 50 and not inner.strip().endswith('.'):
            continue
        # - It's in quotes
        if inner.startswith('"') or inner.startswith("'") or inner.startswith('\u201c'):
            continue
        # - It contains a colon (Label: Description pattern)
        if ':' in inner and len(inner.split(':')[0]) <= 40:
            # This is a "Label: description" pattern - keep the label bold only
            parts = inner.split(':', 1)
            label = parts[0].strip()
            desc = parts[1].strip() if len(parts) > 1 else ''
            if desc:
                replacements.append((full, f'**{label}:** {desc}'))
            continue
        # - It's a numbered item or starts with a number
        if re.match(r'^\d+\.?\s', inner):
            continue
        
        # REMOVE bold if:
        # - It's a full sentence (> 60 chars and ends with . or ?)
        if len(inner) > 60:
            replacements.append((full, inner))
            continue
        # - It's a long phrase ending with period
        if inner.strip().endswith('.') and len(inner) > 40:
            replacements.append((full, inner))
            continue
        # - The entire line is just this one bold segment
        if stripped == full:
            if len(inner) > 60:
                replacements.append((full, inner))
                continue
    
    for old, new in replacements:
        result = result.replace(old, new, 1)
    
    return result


def add_line_breaks_between_labels(text):
    """
    Add line breaks between labeled items that are mushed together.
    Pattern: "...sentence. **Label:** More text" -> "...sentence.\n\n**Label:** More text"
    """
    # Add breaks before bold labels that follow regular text
    text = re.sub(
        r'([.!?])\s+(\*\*[A-Z][^*]+:\*\*)',
        r'\1\n\n\2',
        text
    )
    # Also for "**Label**: description" pattern
    text = re.sub(
        r'([.!?])\s+(\*\*[A-Z][^*]+\*\*:)',
        r'\1\n\n\2',
        text
    )
    return text


def fix_mismatched_bold_markers(text):
    """Fix cases where ** markers don't pair properly."""
    # Count ** markers
    count = text.count('**')
    if count % 2 != 0:
        # Odd number of ** markers - find and fix orphans
        # Common pattern: **Label: description.**  (closing ** at wrong place)
        # Fix: **Label:** description.
        pass
    
    # Fix pattern: **text**: more text.** -> **text:** more text.
    text = re.sub(
        r'\*\*([^*]+)\*\*:\s*([^*]+)\.\*\*',
        r'**\1:** \2.',
        text
    )
    
    # Fix pattern: **text: more text** (too much bolded after colon)
    # Only fix if the total is > 80 chars
    def fix_bold_label_desc(m):
        full = m.group(0)
        inner = m.group(1)
        if ':' in inner and len(inner) > 80:
            parts = inner.split(':', 1)
            return f'**{parts[0].strip()}:** {parts[1].strip()}'
        return full
    
    text = re.sub(r'\*\*([^*]{80,}?)\*\*', fix_bold_label_desc, text)
    
    return text


def wrap_plain_scripture_in_red(text):
    """
    Find plain-text scripture references and wrap them in {red|}.
    Only wraps the reference itself, not surrounding quote text.
    Patterns like: (Proverbs 15:1) or , James 1:19 or - Romans 12:2
    """
    def wrap_ref(m):
        full_match = m.group(0)
        book = m.group(1)
        verse = m.group(2)
        ref = f'{book} {verse}'
        
        # Check if already inside a {red|} tag by looking at context
        start = m.start()
        # Look back for {red| 
        before = text[max(0, start-20):start]
        if '{red|' in before and '}' not in before[before.rfind('{red|'):]:
            return full_match  # Already inside a red tag
        
        return full_match.replace(ref, '{red|' + ref + '}')
    
    result = text
    for m in reversed(list(SCRIPTURE_REF_RE.finditer(text))):
        book = m.group(1)
        verse = m.group(2)
        ref = f'{book} {verse}'
        start = m.start()
        
        # Check if already inside a {red|} tag
        before = text[max(0, start-20):start]
        if '{red|' in before and '}' not in before[before.rfind('{red|'):]:
            continue
        
        result = result[:m.start()] + '{red|' + ref + '}' + result[m.end():]
    
    return result


def fix_bold_in_red_display(text):
    """Remove ** markers that leaked into {red|} display text."""
    def clean_display(m):
        ref = m.group(1)
        display = m.group(2)
        # Remove ** from display text
        clean = display.replace('**', '')
        if clean.strip():
            return '{red|' + ref + '|' + clean + '}'
        return '{red|' + ref + '}'
    
    return re.sub(r'\{red\|([^|]+)\|([^}]*\*\*[^}]*)\}', clean_display, text)


def normalize_scripture_refs(text):
    """Apply all scripture reference normalizations."""
    text = fix_double_parens_scripture(text)
    text = fix_book_number_outside_red(text)
    text = fix_bold_in_red_display(text)
    text = fix_red_with_display_text_abuse(text)
    text = fix_empty_red_tags(text)
    return text


def process_text_field(text, card_type, file_category):
    """Apply all formatting fixes to a text field."""
    if not text or not isinstance(text, str):
        return text
    
    original = text
    
    # Step 1: Fix broken {red|} tags
    text = normalize_scripture_refs(text)
    text = fix_fragmented_red_tags(text)
    
    # Step 2: Remove {red|} from entire question/reflection text
    if card_type in ('question', 'reflection'):
        text = fix_red_wrapping_entire_text(text, card_type)
    
    # Step 3: Fix mismatched bold markers
    text = fix_mismatched_bold_markers(text)
    
    # Step 4: Remove excessive bolding (mainly married/divorced/widowed)
    if file_category != "singles journeys":
        text = remove_excessive_bold(text, card_type)
    
    # Step 5: Add line breaks between labeled items
    text = add_line_breaks_between_labels(text)
    
    # Step 6: Wrap untagged scripture references in {red|}
    text = wrap_plain_scripture_in_red(text)
    
    # Clean up: remove double spaces, fix trailing whitespace
    text = re.sub(r'  +', ' ', text)
    text = re.sub(r' +\n', '\n', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    return text


def process_card(card, file_category):
    """Process a single card dictionary."""
    card_type = card.get('cardType', card.get('type', 'teaching')).lower()
    
    # Process text field
    if 'text' in card and card['text']:
        card['text'] = process_text_field(card['text'], card_type, file_category)
    
    # Process reflection field (widowed files)
    if 'reflection' in card and card['reflection']:
        card['reflection'] = process_text_field(
            card['reflection'], 'reflection', file_category
        )
    
    # Process bullets
    if 'bullets' in card and card['bullets']:
        card['bullets'] = [
            process_text_field(b, card_type, file_category)
            for b in card['bullets']
        ]
    
    # Process prompts (if they're strings)
    if 'prompt' in card and card['prompt']:
        card['prompt'] = process_text_field(
            card['prompt'], card_type, file_category
        )
    
    return card


def process_activity(activity, file_category):
    """Process all cards within an activity."""
    if 'cards' in activity:
        for i, card in enumerate(activity['cards']):
            activity['cards'][i] = process_card(card, file_category)
    return activity


def process_file(filepath, file_category):
    """Process a single journey JSON file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    # Find the activities/missions list
    activities_key = None
    for key in ['activities', 'missions', 'lessons', 'steps', 'modules']:
        if key in data and isinstance(data[key], list):
            activities_key = key
            break
    
    if not activities_key:
        print(f"  WARNING: No activities found in {filepath}")
        return False
    
    for i, activity in enumerate(data[activities_key]):
        data[activities_key][i] = process_activity(activity, file_category)
    
    updated = json.dumps(data, ensure_ascii=False)
    
    if original == updated:
        return False
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    
    return True


def main():
    total = 0
    modified = 0
    errors = 0
    
    for category, files in FILES.items():
        folder = os.path.join(JOURNEYS_DIR, category)
        print(f"\n=== Processing {category} ({len(files)} files) ===")
        
        for filename in files:
            filepath = os.path.join(folder, filename)
            if not os.path.exists(filepath):
                print(f"  MISSING: {filename}")
                errors += 1
                continue
            
            total += 1
            try:
                changed = process_file(filepath, category)
                if changed:
                    modified += 1
                    print(f"  ✓ Modified: {filename}")
                else:
                    print(f"  · Unchanged: {filename}")
            except Exception as e:
                print(f"  ✗ Error in {filename}: {e}")
                errors += 1
    
    print(f"\n=== Summary ===")
    print(f"Total files: {total}")
    print(f"Modified: {modified}")
    print(f"Errors: {errors}")
    print(f"Unchanged: {total - modified - errors}")


if __name__ == '__main__':
    main()

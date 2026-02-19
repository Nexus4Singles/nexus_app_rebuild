#!/usr/bin/env python3
"""
Content Quality Fix Script - Handles ALL 65 journey files.
Fixes:
1. Inline bullets on same line: "• item1 • item2" → "• item1\n• item2"
2. Labeled items packed together: "desc. **Label.** desc" → add \n\n between
3. Missing line breaks after bold closings: ".**Word" → ".**\n\nWord"
4. Missing line breaks where sentences run together: ".Word" → ".\n\nWord"
5. Missing \n after section headers before bullets: ":**•" → ":**\n•"
6. Broken bold openings: "Word:**" at start of line → "**Word:**"
"""

import json
import os
import re
import sys

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

change_log = []

def log_change(file, card_title, change_type, context=""):
    change_log.append(f"  [{change_type}] {card_title}: {context[:80]}")

def fix_inline_bullets(text, title, fname):
    """Fix bullets crammed on same line: '• item1 • item2' → '• item1\n• item2'"""
    original = text
    # Pattern: non-newline followed by space then bullet char
    # Match " • " that is NOT preceded by a newline
    text = re.sub(r'(?<!\n) (•) ', r'\n\1 ', text)
    # Also handle "Text• " (no space before bullet)
    text = re.sub(r'(?<!\n)(•) ', r'\n\1 ', text)
    if text != original:
        log_change(fname, title, "INLINE_BULLETS", "Split bullets onto separate lines")
    return text

def fix_labeled_items_packed(text, title, fname):
    """
    Fix labeled items packed together without line breaks.
    Pattern: 'description. **Label.** description **Label2.: ' or similar.
    Add \n\n before each **Label pattern that follows end of sentence.
    """
    original = text
    
    # Pattern 1: sentence ending (.!?") followed by space and **BoldLabel
    # "description. **NextLabel.** description" → "description.\n\n**NextLabel.** description"
    text = re.sub(
        r'([.!?\u201d"]) (\*\*[A-Z])',
        r'\1\n\n\2',
        text
    )
    
    # Pattern 2: sentence ending (.!?) followed by **CloseBold then space and capital letter
    # "sentence.**\n\nWord" is fine, but "sentence.** Word" needs \n\n
    # But NOT when it's "**Label:** description. **Next"  (already handled above)
    
    if text != original:
        log_change(fname, title, "LABELED_ITEMS", "Added \\n\\n between labeled items")
    return text

def fix_bold_close_then_sentence(text, title, fname):
    """
    Fix missing line breaks after bold closings before new sentences.
    Pattern: '.**Word' → '.**\n\nWord'
    """
    original = text

    # Pattern: period/exclamation/question then ** then capital letter (no newline between)
    text = re.sub(
        r'([.!?])\*\*\s*([A-Z][a-z])',
        r'\1**\n\n\2',
        text
    )
    
    if text != original:
        log_change(fname, title, "BOLD_CLOSE_BREAK", "Added \\n\\n after bold close before sentence")
    return text

def fix_sentences_run_together(text, title, fname):
    """
    Fix where sentences run together without breaks.
    Pattern: 'word.Word' → 'word.\n\nWord' or 'word. Word'
    But be careful not to break abbreviations (Dr., vs., etc.)
    """
    original = text
    
    # Pattern: lowercase letter then period then UPPERCASE letter (no space)
    # "fail.Avoid" → "fail.\n\nAvoid"
    # But NOT "vs.Do" → handle with care
    text = re.sub(
        r'([a-z])\.\s*([A-Z][a-z]{2,})',  # at least 3 chars after capital to avoid "vs.Do"
        lambda m: m.group(1) + '.\n\n' + m.group(2) if m.group(2) not in ['In', 'It', 'Is', 'If', 'Or', 'Do', 'No'] or len(m.group(2)) > 3 else m.group(1) + '. ' + m.group(2),
        text
    )
    
    # Also fix "wordWord" (no period, just smooshed) for common patterns  
    # "returnListening" → "return\n\nListening"
    # This is risky, so be conservative - only when a lowercase word is immediately followed by uppercase
    # Let's skip this and handle manually if needed
    
    if text != original:
        log_change(fname, title, "SENTENCES_TOGETHER", "Added breaks between run-together sentences")
    return text

def fix_header_before_bullets(text, title, fname):
    """
    Fix missing newline after section header before bullets.
    Pattern: ':**•' → ':**\n•'  OR ':**\n• ' (already fine)
    """
    original = text
    
    # Pattern: colon then ** close then immediately bullet
    text = re.sub(r':\*\*\s*•', r':**\n•', text)
    
    # Pattern: colon then immediately bullet (no ** involved)
    text = re.sub(r':\s*•(?!\s*\n)', r':\n•', text)
    
    if text != original:
        log_change(fname, title, "HEADER_BULLETS", "Added \\n after header before bullets")
    return text

def fix_broken_bold_openings(text, title, fname):
    """
    Fix broken bold where opening ** is missing.
    Pattern at start of line: 'Word:**' should be '**Word:**'
    Pattern in text: 'Description.Word:**' → 'Description.\n\n**Word:**'
    """
    original = text
    
    # Pattern: After \n\n, a word followed by :** without opening **
    # "Decide together:**" → "**Decide together:**"
    text = re.sub(
        r'(?<=\n)([A-Z][a-z][\w\s]{2,40}):\*\*',
        r'**\1:**',
        text
    )
    
    # Pattern: After sentence end, a word followed by :**
    # "...resolved.For black flags:**" → "...resolved.\n\n**For black flags:**"
    text = re.sub(
        r'([.!?])\s*([A-Z][a-z][\w\s]{2,40}):\*\*',
        r'\1\n\n**\2:**',
        text
    )
    
    if text != original:
        log_change(fname, title, "BROKEN_BOLD", "Fixed broken bold openings")
    return text

def fix_missing_bold_on_labels(text, title, fname):
    """
    In a sequence of labeled items where most are bold (**Label:**),
    fix the ones that are missing bold.
    Only applies when >50% of items in a list are already bold.
    """
    original = text
    lines = text.split('\n')
    
    # Count bold vs non-bold labels in text
    bold_labels = re.findall(r'\*\*[^*]+\*\*:', text)
    # Non-bold labels: "Word: " at start of line or after \n\n
    nonbold_labels = re.findall(r'(?:^|\n)([A-Z][a-z][\w\s]{2,30}): (?=[A-Z])', text)
    
    if len(bold_labels) >= 3 and len(nonbold_labels) >= 1:
        # Make non-bold labels bold too
        # Pattern: after \n\n or start of line, "Label: Description" → "**Label:** Description"
        text = re.sub(
            r'(?<=\n\n)([A-Z][a-z][\w\s]{2,30}): (?=[A-Z])',
            r'**\1:** ',
            text
        )
        text = re.sub(
            r'(?<=\n)([A-Z][a-z][\w\s]{2,30}): (?=[A-Z])',
            r'**\1:** ',
            text
        )
    
    if text != original:
        log_change(fname, title, "MISSING_BOLD_LABELS", "Added bold to inconsistent labels")
    return text

def fix_double_bold_close(text, title, fname):
    """Fix patterns like 'rights.** What' where ** is doubled at end of bold."""
    original = text
    # Pattern: word.**<space> (this is an extra ** closing)
    # "independence, and individual rights.** What's best" 
    # This seems like the bold should end at "rights." and not include the period
    # Actually this is: **Individualistic cultures** emphasize personal achievement, independence, and individual rights.** What's best
    # The second ** is stray. Remove it.
    text = re.sub(r'([a-z])\.\*\*\s+([A-Z])', r'\1.\n\n\2', text)
    
    if text != original:
        log_change(fname, title, "DOUBLE_BOLD_CLOSE", "Fixed stray ** after period")
    return text

def fix_stray_bold_in_response(text, title, fname):
    """Fix 'response:**' type patterns where ** is stray."""
    original = text
    # "Watch for response:** defensiveness" → "Watch for response: defensiveness"
    text = re.sub(r'(\w):\*\*\s+', r'\1: ', text)
    if text != original:
        log_change(fname, title, "STRAY_BOLD", "Removed stray ** after colon")
    return text

def fix_stray_red_tags(text, title, fname):
    """Fix broken/empty {red} tags."""
    original = text
    # Remove {red} with no content (empty red tags)
    text = re.sub(r'\{red\}\s*$', '', text)
    text = re.sub(r'\{red\}\s*', '', text)
    # Fix {red text} (missing pipe)
    text = re.sub(r'\{red ([^|}]+)\}', r'{red|\1}', text)
    if text != original:
        log_change(fname, title, "STRAY_RED", "Fixed broken/empty red tags")
    return text

def cleanup_whitespace(text):
    """Normalize excessive whitespace."""
    # Fix triple+ newlines to double
    text = re.sub(r'\n{3,}', '\n\n', text)
    # Fix space before newline
    text = re.sub(r' +\n', '\n', text)
    # Fix multiple spaces (but not in indentation)
    text = re.sub(r'(?<!\n)  +', ' ', text)
    return text.strip()


def process_text(text, title, fname):
    """Apply all fixes to a text field."""
    if not text or not isinstance(text, str):
        return text
    
    # Order matters! Apply fixes in this sequence:
    text = fix_stray_red_tags(text, title, fname)
    text = fix_stray_bold_in_response(text, title, fname)
    text = fix_double_bold_close(text, title, fname)
    text = fix_broken_bold_openings(text, title, fname)
    text = fix_inline_bullets(text, title, fname)
    text = fix_header_before_bullets(text, title, fname)
    text = fix_labeled_items_packed(text, title, fname)
    text = fix_bold_close_then_sentence(text, title, fname)
    text = fix_sentences_run_together(text, title, fname)
    text = fix_missing_bold_on_labels(text, title, fname)
    text = cleanup_whitespace(text)
    
    return text


def process_card(card, fname):
    """Process a single card."""
    title = card.get('title', card.get('cardId', card.get('id', 'unknown')))
    
    for field in ['text', 'reflection', 'prompt']:
        if field in card and card[field] and isinstance(card[field], str):
            card[field] = process_text(card[field], title, fname)
    
    # Process bullets too
    if 'bullets' in card and card['bullets']:
        card['bullets'] = [
            process_text(b, title, fname) if isinstance(b, str) else b
            for b in card['bullets']
        ]
    
    return card


def process_file(filepath, fname):
    """Process a single file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    original = json.dumps(data, ensure_ascii=False)
    
    for key in ['activities', 'missions']:
        if key not in data:
            continue
        for activity in data[key]:
            for i, card in enumerate(activity.get('cards', [])):
                activity['cards'][i] = process_card(card, fname)
    
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
                print(f"  ! MISSING: {fname}")
                continue
            total += 1
            
            change_log.clear()
            try:
                if process_file(filepath, fname):
                    modified += 1
                    print(f"  + {fname}")
                    for entry in change_log:
                        print(entry)
                else:
                    print(f"  . {fname}")
            except Exception as e:
                print(f"  ! {fname}: {e}")
                import traceback
                traceback.print_exc()
    
    print(f"\n=== Done: {modified}/{total} modified ===")


if __name__ == '__main__':
    main()

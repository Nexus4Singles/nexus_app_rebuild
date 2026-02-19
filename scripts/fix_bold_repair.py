#!/usr/bin/env python3
"""
Fix Pass 2: Repair bold markup and word-boundary issues from content quality pass.

Key issues to fix:
1. Restore closing ** on labels: **Label text.\n\n → **Label text.**\n\n
2. Fix words running together: wordWord → word.\n\nWord or word\n\nWord
3. Fix unclosed bold tags (odd ** count)
4. Fix missing opening ** on labels that should be bold
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

change_log = []


def log_change(fname, title, change_type, detail=""):
    change_log.append(f"  [{change_type}] {title}: {detail[:100]}")


def count_bold_markers(text):
    """Count ** markers outside {red|} blocks."""
    return len(re.findall(r'\*\*', text))


def fix_unclosed_bold_labels(text, title, fname):
    """
    Fix pattern where **Label text. is missing closing **.
    Pattern: **ShortLabel.\n\n  → **ShortLabel.**\n\n
    Only for short labels (< 60 chars after **)
    """
    original = text

    # Pattern: ** followed by short text (no ** inside) ending in period followed by \n\n
    # **Label text.\n\n → **Label text.**\n\n
    def fix_unclosed(m):
        label = m.group(1)
        # Don't fix if it already has ** at end or if too long (likely a deliberate bold sentence)
        if len(label) > 60:
            return m.group(0)
        return f"**{label}**\n\n"

    text = re.sub(
        r'\*\*([^*\n]{2,60}\.)\n\n',
        fix_unclosed,
        text
    )

    # Also fix at end of text: **Label text.$ → **Label text.**
    text = re.sub(
        r'\*\*([^*\n]{2,60}\.)$',
        r'**\1**',
        text
    )

    if text != original:
        log_change(fname, title, "RESTORE_BOLD_CLOSE", "Added closing ** to unclosed labels")
    return text


def fix_words_running_together(text, title, fname):
    """
    Fix cases where words run together with no space/break.
    Pattern: lowercaseUPPERCASE → lowercase\n\nUPPERCASE
    """
    original = text

    # Pattern: lowercase letter directly touching uppercase letter (no period between)
    # "returnListening" → "return\n\nListening"
    # "resolvedFor" → "resolved\n\nFor"
    # "orientedThe" → "oriented\n\nThe"
    # "familyNeither" → "family\n\nNeither"
    # But NOT: "JavaScript", "iPhone", etc.
    # Heuristic: only if the uppercase letter starts a word of 4+ chars
    text = re.sub(
        r'([a-z])([A-Z][a-z]{3,})',
        lambda m: m.group(1) + '\n\n' + m.group(2) if m.group(2) not in [
            'Script', 'Phone', 'Mail', 'Tube', 'Book', 'Type',
        ] else m.group(0),
        text
    )

    if text != original:
        log_change(fname, title, "WORDS_TOGETHER", "Added breaks between run-together words")
    return text


def fix_period_then_sentence(text, title, fname):
    """
    Fix missing space/break after period before new sentence.
    "vs.do" → "vs. do"
    """
    original = text

    # Fix "vs.something" (abbreviation followed by lowercase)
    text = re.sub(r'vs\.([a-z])', r'vs. \1', text)

    if text != original:
        log_change(fname, title, "PERIOD_SPACE", "Added space after period")
    return text


def fix_unclosed_bold_headers(text, title, fname):
    """
    Fix bold section headers that open ** but don't close.
    Pattern: **Header text:\n or **Header text: followed by bullets
    → **Header text:**\n
    """
    original = text

    # Pattern: **Word(s): followed by \n (should be **Word(s):**\n)
    text = re.sub(
        r'\*\*([^*\n]{2,50}):\n',
        r'**\1:**\n',
        text
    )

    # Pattern: **Word(s): followed by space then description text
    # But only if it's a header-like pattern (short, ends with colon)
    # This is tricky - the ** might be intentionally bold inline text

    if text != original:
        log_change(fname, title, "BOLD_HEADER_CLOSE", "Closed bold on section headers")
    return text


def fix_missing_bold_opening(text, title, fname):
    """
    Fix labels at start of line that have closing ** but no opening:
    "Internal processors** think" → "**Internal processors** think"
    """
    original = text

    # Pattern: After \n\n or start, a capitalized word(s) ending in **
    text = re.sub(
        r'(?<=\n\n)([A-Z][a-z][\w\s]{2,40})\*\*',
        r'**\1**',
        text
    )
    # Also at very start of text
    text = re.sub(
        r'^([A-Z][a-z][\w\s]{2,40})\*\*',
        r'**\1**',
        text
    )

    if text != original:
        log_change(fname, title, "MISSING_BOLD_OPEN", "Added missing opening ** to labels")
    return text


def fix_inconsistent_labels(text, title, fname):
    """
    In a list of labeled items, if most have **bold** labels,
    make the non-bold ones bold too.
    """
    original = text

    # Count bold labels (on their own line or after \n\n)
    bold_labels = re.findall(r'(?:^|\n\n)\*\*[^*]+\*\*:', text)
    # Count non-bold labels that look like they should be bold
    # Pattern: after \n\n, a capitalized label text followed by colon
    nonbold_labels = re.findall(r'\n\n([A-Z][a-z][\w\s]{2,40}:) ', text)

    if len(bold_labels) >= 2 and len(nonbold_labels) >= 1:
        # Make non-bold labels bold
        for label in nonbold_labels:
            label_text = label.rstrip(':')
            text = text.replace(
                f'\n\n{label} ',
                f'\n\n**{label_text}:** '
            )

    if text != original:
        log_change(fname, title, "INCONSISTENT_LABELS", f"Bolded {len(nonbold_labels)} non-bold labels")
    return text


def fix_unclosed_singleton_bold(text, title, fname):
    """
    If text has odd number of ** markers, try to fix.
    Common pattern: **Label without close at end of text or before \n\n.
    """
    original = text
    count = count_bold_markers(text)

    if count % 2 == 0:
        return text  # Even = balanced

    # Strategy: find each ** and check if it has a pair
    # For now, focus on the specific pattern of **Text: (header without closing)
    # that appears at beginning of text
    text = re.sub(
        r'^(\*\*[^*\n:]{2,50}: )',
        lambda m: m.group(1).replace('**', '**', 1) + '** ' if ':**' not in m.group(1) else m.group(0),
        text
    )

    # If still odd, check for **Text. at end without close
    count = count_bold_markers(text)
    if count % 2 != 0:
        # Try to find the unpaired ** and add its closing
        # Find all ** positions
        positions = [m.start() for m in re.finditer(r'\*\*', text)]
        if positions:
            # Check if last ** is an opener (odd index in sequence)
            if len(positions) % 2 != 0:
                last_pos = positions[-1]
                # Find next sentence boundary after the last **
                after = text[last_pos + 2:]
                m = re.search(r'[.!?:]\s', after)
                if m:
                    insert_pos = last_pos + 2 + m.start() + 1
                    text = text[:insert_pos] + '**' + text[insert_pos:]
                    log_change(fname, title, "ODD_BOLD_FIX", f"Closed unpaired ** near pos {last_pos}")

    if text != original and text == original:
        pass  # no change
    elif text != original:
        log_change(fname, title, "ODD_BOLD_FIX", "Fixed odd bold marker count")

    return text


def process_text(text, title, fname):
    """Apply all fixes to a text field."""
    if not text or not isinstance(text, str):
        return text

    text = fix_unclosed_bold_labels(text, title, fname)
    text = fix_unclosed_bold_headers(text, title, fname)
    text = fix_missing_bold_opening(text, title, fname)
    text = fix_words_running_together(text, title, fname)
    text = fix_period_then_sentence(text, title, fname)
    text = fix_inconsistent_labels(text, title, fname)
    text = fix_unclosed_singleton_bold(text, title, fname)

    # Final cleanup
    text = re.sub(r'\n{3,}', '\n\n', text)
    text = text.strip()

    return text


def process_card(card, fname):
    """Process a single card."""
    title = card.get('title', card.get('cardId', card.get('id', 'unknown')))

    for field in ['text', 'reflection', 'prompt']:
        if field in card and card[field] and isinstance(card[field], str):
            card[field] = process_text(card[field], title, fname)

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

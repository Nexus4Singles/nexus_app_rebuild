#!/usr/bin/env python3
"""Replace em dashes in all assessment JSON fields with contextual punctuation."""

import json
import re
import os

ASSESSMENT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'config', 'assessments')

FILES = [
    'singles_readiness_v1.json',
    'remarriage_divorced_final.json',
    'remarriage_widowed_final.json',
    'marriage_health_check_v1.json',
]

# Words that get a comma before them (continuation/aside)
COMMA_WORDS = {
    'but', 'and', 'or', 'not', 'even', 'rather', 'especially', 'often',
    'for', 'both', 'whether', 'while', 'which', 'where', 'when', 'just',
    'yet', 'so', 'without', 'only', 'never', 'no', 'nor', 'probably',
    'maybe', 'perhaps', 'still', 'also', 'either', 'neither', 'doing',
    'freeing', 'leaving', 'making', 'letting', 'allowing', 'creating',
    'building', 'bringing', 'giving', 'watching', 'waiting', 'hoping',
    'meaning', 'saying', 'feeling', 'thinking', 'knowing', 'showing',
    'running', 'turning', 'pulling', 'pushing', 'keeping', 'holding',
    'carrying', 'leading', 'missing', 'causing', 'preventing', 'protecting',
    'mistakes', 'silence', 'people', 'because',
}


def replace_emdash_segment(before_char, after_text):
    """Given context, pick the right replacement for an em dash."""
    if not after_text:
        return '; '

    # Check if starts with a quote
    if after_text[0] in ("'", '"', '\u2018', '\u201C'):
        return ': '
    # Check if starts with uppercase
    elif after_text[0].isupper():
        first_word = after_text.split()[0].rstrip('.,;:!?') if after_text.split() else ''
        if first_word.lower() in COMMA_WORDS:
            return ', '
        return '. '
    # Lowercase - check if comma word
    else:
        first_word = after_text.split()[0].rstrip('.,;:!?') if after_text.split() else ''
        if first_word in COMMA_WORDS:
            return ', '
        return '; '


def replace_emdash(text):
    """Replace all em dashes with contextually appropriate punctuation."""
    if '—' not in text:
        return text

    # Handle " — " (with spaces)
    result = text
    while ' — ' in result:
        idx = result.index(' — ')
        before = result[:idx]
        after = result[idx + 3:]
        sep = replace_emdash_segment(before[-1] if before else '', after)
        # If separator already has a space, trim trailing space from before
        result = before + sep + after

    # Handle "—" without spaces (word—word)
    while '—' in result:
        idx = result.index('—')
        before = result[:idx]
        after = result[idx + 1:]
        sep = replace_emdash_segment(before[-1] if before else '', after)
        result = before + sep + after

    return result


def process_value(obj):
    """Recursively process all string values in a JSON object."""
    count = 0
    if isinstance(obj, dict):
        for key in obj:
            if isinstance(obj[key], str) and '—' in obj[key]:
                new_val = replace_emdash(obj[key])
                if new_val != obj[key]:
                    count += obj[key].count('—')
                    obj[key] = new_val
            elif isinstance(obj[key], (dict, list)):
                count += process_value(obj[key])
    elif isinstance(obj, list):
        for item in obj:
            count += process_value(item)
    return count


def main():
    total = 0
    for fname in FILES:
        fpath = os.path.join(ASSESSMENT_DIR, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            data = json.load(f)

        count = process_value(data)
        total += count

        with open(fpath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            f.write('\n')

        print(f'{fname}: {count} em dashes replaced')

    print(f'\nTotal: {total} em dashes replaced')


if __name__ == '__main__':
    main()

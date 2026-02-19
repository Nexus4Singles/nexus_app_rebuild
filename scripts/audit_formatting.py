#!/usr/bin/env python3
"""Audit remaining formatting issues in journey JSON files."""
import json, os, re

base = 'assets/config/journeys'
# Only audit active files
active_files = {
    'singles journeys': [
        'singles_journey_01_identity_self_worth.json',
        'singles_journey_02_cultural_lies.json',
        'singles_journey_03_healing_past_wounds.json',
        'singles_journey_04_family_patterns.json',
        'singles_journey_05_emotional_readiness.json',
        'singles_journey_06_emotional_intelligence.json',
        'singles_journey_07_secure_confidence.json',
        'singles_journey_08_toxic_triggers.json',
        'singles_journey_09_biblical_femininity.json',
        'singles_journey_09_biblical_masculinity.json',
        'singles_journey_10_communicate_better.json',
        'singles_journey_11_healthy_boundaries.json',
        'singles_journey_12_financial_readiness.json',
        'singles_journey_13_red_flags.json',
        'singles_journey_14_compatibility.json',
        'singles_journey_15_dating_purpose.json',
        'singles_journey_16_sexual_chemistry.json',
        'singles_journey_17_faith_alignment.json',
        'singles_journey_18_purity.json',
        'singles_journey_19_choosing_spouse.json',
        'singles_journey_20_fear_commitment.json',
    ],
    'married journeys': [f'married_journey_{str(i).zfill(2)}_{n}.json' for i, n in [
        (1,'communication_conflict'),(2,'harmful_conflict_patterns'),(3,'restoring_friendship'),
        (4,'emotional_physical_intimacy'),(5,'keeping_romance_alive'),(6,'reigniting_sexual_desire'),
        (7,'rebuilding_trust'),(8,'handling_infidelity'),(9,'roles_expectations'),
        (10,'masculinity_femininity'),(11,'cultural_differences'),(12,'managing_finances'),
        (13,'parenting_united_team'),(14,'infertility'),(15,'healthy_boundaries_extended_family'),
        (16,'personal_growth'),(17,'faith_spiritual_unity'),(18,'shared_purpose_vision'),
    ]],
    'divorced journeys': [f'divorced_journey_{str(i).zfill(2)}_{n}.json' for i, n in [
        (1,'understanding_what_went_wrong'),(2,'processing_pain'),(3,'healing_restoration'),
        (4,'identity_selfworth'),(5,'letting_go_resentment'),(6,'faith_church_community'),
        (7,'financial_recovery'),(8,'coparenting'),(9,'anniversaries_occasions'),
        (10,'ex_moves_on'),(11,'developing_trust'),(12,'toxic_patterns'),
        (13,'emotional_readiness'),(14,'discerning_healthy_love'),(15,'dating_again'),
        (16,'preparing_new_covenant'),
    ]],
    'widowed journeys': [f'widowed_journey_{str(i).zfill(2)}_{n}.json' for i, n in [
        (1,'navigating_grief_loss'),(2,'staying_present_for_kids'),(3,'dealing_with_loneliness'),
        (4,'rebuilding_life'),(5,'holidays_anniversaries'),(6,'rediscovering_identity'),
        (7,'honoring_memory'),(8,'opening_heart_new_love'),(9,'kids_embrace_new_commitment'),
        (10,'preparing_new_covenant'),
    ]],
}
issues = []

for cat, files in active_files.items():
    folder = os.path.join(base, cat)
    for fname in files:
        path = os.path.join(folder, fname)
        with open(path) as f:
            data = json.load(f)
        
        activities_key = None
        for k in ['activities', 'missions']:
            if k in data and isinstance(data[k], list):
                activities_key = k
                break
        if not activities_key:
            continue
        
        for act in data[activities_key]:
            act_num = act.get('activityNumber', act.get('missionNumber', '?'))
            for card in act.get('cards', []):
                card_id = card.get('cardId', card.get('id', '?'))
                for field in ['text', 'reflection']:
                    text = card.get(field, '')
                    if not text or not isinstance(text, str):
                        continue
                    
                    # Mismatched {red| and }
                    opens = text.count('{red|')
                    # Count } that are part of {red|} (not just any })
                    if opens > 0:
                        # Simple heuristic: find {red| ... } pairs
                        remaining = text
                        matched = 0
                        while '{red|' in remaining:
                            idx = remaining.index('{red|')
                            close = remaining.find('}', idx + 5)
                            if close >= 0:
                                matched += 1
                                remaining = remaining[close+1:]
                            else:
                                break
                        if matched != opens:
                            issues.append(f'BROKEN_RED: {fname} act{act_num} {card_id}.{field}: opens={opens} matched={matched}')

                    # Entire text wrapped in {red|}
                    stripped = text.strip()
                    if stripped.startswith('{red|') and len(stripped) > 100:
                        # Check if it closes at the very end
                        depth = 0
                        for i, ch in enumerate(stripped):
                            if stripped[i:i+5] == '{red|':
                                depth += 1
                            elif ch == '}' and depth > 0:
                                depth -= 1
                                if depth == 0 and i == len(stripped) - 1:
                                    issues.append(f'WHOLE_RED: {fname} act{act_num} {card_id}.{field}: len={len(stripped)}')

                    # Odd ** count
                    bold_count = text.count('**')
                    if bold_count % 2 != 0:
                        issues.append(f'ODD_BOLD: {fname} act{act_num} {card_id}.{field}: count={bold_count}')
                    
                    # Long bold segments (>80 chars)
                    for m in re.finditer(r'\*\*(.+?)\*\*', text):
                        if len(m.group(1)) > 80:
                            issues.append(f'LONG_BOLD: {fname} act{act_num} {card_id}.{field}: ({len(m.group(1))} chars) "{m.group(1)[:60]}..."')
                    
                    # {red| with display text containing ** 
                    for m in re.finditer(r'\{red\|[^|]+\|([^}]*)\}', text):
                        if '**' in m.group(1):
                            issues.append(f'BOLD_IN_RED: {fname} act{act_num} {card_id}.{field}: {m.group(0)[:80]}...')
                    
                    # Literal "{red|" showing as text (malformed)
                    if '{red)' in text or '|**}' in text:
                        issues.append('MALFORMED: %s act%s %s.%s: contains broken markers' % (fname, act_num, card_id, field))

for issue in issues:
    print(issue)
print(f'\nTotal remaining issues: {len(issues)}')

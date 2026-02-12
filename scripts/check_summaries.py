import json, re

def shorten(text, max_sentences=3):
    matches = list(re.finditer(r'(?<=[.!?])\s+', text))
    if len(matches) < max_sentences:
        return text
    end = 0
    for i, m in enumerate(matches):
        end = m.start()
        if i + 1 >= max_sentences:
            break
    if end > 0 and end < len(text):
        return text[:end+1].strip()
    return text

for fname in ['singles_readiness_v1.json', 'remarriage_divorced_final.json', 'remarriage_widowed_final.json', 'marriage_health_check_v1.json']:
    try:
        with open(f'assets/config/assessments/{fname}') as f:
            data = json.load(f)
        profiles = data.get('profiles', {})
        print(f'\n========== {fname} ==========')
        for tier, profile in profiles.items():
            summary = profile.get('summary', '')
            shortened = shorten(summary)
            print(f'\n--- {tier} ({len(summary)} -> {len(shortened)} chars) ---')
            print(shortened)
            print()
    except Exception as e:
        print(f'Error with {fname}: {e}')

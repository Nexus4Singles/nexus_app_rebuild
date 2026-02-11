import json
with open('/Users/aybaj/Documents/nexus_app_v2/assets/config/assessments/singles_readiness_v1.json') as f:
    data = json.load(f)
dims = data['dimensions']
print(f"Total dimensions: {len(dims)}")
all_ok = True
for d in dims:
    ins = d['insights']
    has_gender = all(k in ins for k in ['genderLow','genderMedium','genderHigh','genderMicroStep'])
    has_orig = all(k in ins for k in ['low','medium','high','microStep','recommendedJourney'])
    status = 'OK' if (has_gender and has_orig) else 'MISSING'
    if status != 'OK':
        all_ok = False
    print(f"  {d['id']}: {status}")
print(f"\nJSON valid: YES")
print(f"All dimensions complete: {'YES' if all_ok else 'NO'}")

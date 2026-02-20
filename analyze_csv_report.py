import csv
from collections import defaultdict

# Analyze the CSV to get better breakdowns
errors_by_type = defaultdict(int)
warnings_by_type = defaultdict(int)
errors_by_journey = defaultdict(int)
warnings_by_journey = defaultdict(int)

with open('journey_consistency_report.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        journey = row['Journey']
        severity = row['Severity']
        issue = row['Issue']
        
        if severity == 'error':
            errors_by_type[issue] += 1
            errors_by_journey[journey] += 1
        elif severity == 'warning':
            warnings_by_type[issue] += 1
            warnings_by_journey[journey] += 1

print("="*80)
print("ERRORS BY TYPE (CRITICAL)")
print("="*80)
for issue, count in sorted(errors_by_type.items(), key=lambda x: x[1], reverse=True):
    print(f"  • {issue}: {count}")

print("\n" + "="*80)
print("WARNINGS BY TYPE")
print("="*80)
for issue, count in sorted(warnings_by_type.items(), key=lambda x: x[1], reverse=True):
    print(f"  • {issue}: {count}")

print("\n" + "="*80)
print("TOP 15 JOURNEYS WITH MOST ERRORS")
print("="*80)
for journey, count in sorted(errors_by_journey.items(), key=lambda x: x[1], reverse=True)[:15]:
    print(f"  • {journey}: {count} errors")

print("\n" + "="*80)
print("TOP 15 JOURNEYS WITH MOST WARNINGS")
print("="*80)
for journey, count in sorted(warnings_by_journey.items(), key=lambda x: x[1], reverse=True)[:15]:
    print(f"  • {journey}: {count} warnings")

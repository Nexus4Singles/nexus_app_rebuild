import json
import glob

files = glob.glob("/Users/aybaj/Documents/nexus_app_v2/assets/config/journeys/**/*.json", recursive=True)
print(f"Found {len(files)} files")

if files:
    sample = files[0]
    print(f"\nChecking sample file: {sample}")
    with open(sample) as f:
        data = json.load(f)
    print(f"Top-level keys: {list(data.keys())}")
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, list):
                print(f"  - {key}: list with {len(value)} items")
                if value and isinstance(value[0], dict):
                    print(f"    First item keys: {list(value[0].keys())}")
            elif isinstance(value, dict):
                print(f"  - {key}: dict with keys {list(value.keys())}")
            else:
                print(f"  - {key}: {type(value).__name__} = {str(value)[:50]}")

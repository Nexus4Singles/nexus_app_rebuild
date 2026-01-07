import json
from pathlib import Path

# Update ONLY display names. Do NOT touch ids.
RENAMES = {
  "hard_season_coping": "Handling Stress",
  "unresolved_wounds": "Healing From Past Hurt",
  "attachment_security": "Emotional Security",
  "conflict_resolution_pattern": "Conflict Repair Skills",
}

FILES = [
  Path("assets/config/assessments/singles_readiness_v1.json"),
  Path("assets/config/assessments/remarriage_readiness_v1.json"),
  Path("assets/config/assessments/marriage_health_check_v1.json"),
]

def main():
  changed = 0
  for fp in FILES:
    if not fp.exists():
      print(f"SKIP (missing): {fp}")
      continue

    data = json.loads(fp.read_text(encoding="utf-8"))
    dims = data.get("dimensions", [])
    before = json.dumps(dims, sort_keys=True)

    for d in dims:
      did = d.get("id")
      if did in RENAMES:
        d["name"] = RENAMES[did]

    after = json.dumps(dims, sort_keys=True)
    if before != after:
      fp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
      print(f"UPDATED: {fp}")
      changed += 1
    else:
      print(f"NOCHANGE: {fp}")

  print(f"\nDone. Updated {changed} file(s).")

if __name__ == "__main__":
  main()

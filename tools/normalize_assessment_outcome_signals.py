import json
import re
from pathlib import Path

ASSESS_DIR = Path("assets/config/assessments")

def slugify(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s

def normalize_option(option: dict, qid: str, dim: str):
    # 1) Fix unsupported tiers (e.g. RESTORATION) -> DEVELOPING
    tier = (option.get("signalTier") or "").strip().upper()
    if tier == "RESTORATION":
        option["signalTier"] = "DEVELOPING"

    raw = (option.get("outcomeSignal") or "").strip()
    if not raw:
        return

    # If it's already a valid token, leave it.
    if re.fullmatch(r"[a-z0-9_]+", raw):
        return

    # 2) Split "TierLabel: message" patterns
    label = raw
    if ":" in raw:
        left, right = raw.split(":", 1)
        # Keep the right side as the human label if it looks like the sentence part
        right = right.strip()
        if right:
            label = right

    # Special: if label still mentions restoration, keep label but token will be normalized.
    # Preserve the readable string in outcomeLabel
    if "outcomeLabel" not in option:
        option["outcomeLabel"] = label

    # 3) Create stable token outcomeSignal
    base = slugify(label)
    prefix = slugify(qid or dim or "q")
    token = f"{prefix}_{base}" if base else prefix

    option["outcomeSignal"] = token

def normalize_file(path: Path) -> bool:
    data = json.loads(path.read_text(encoding="utf-8"))
    changed = False

    for q in data.get("questions", []):
        qid = (q.get("id") or "").strip()
        dim = (q.get("dimension") or "").strip()

        for opt in q.get("options", []):
            before = (opt.get("signalTier"), opt.get("outcomeSignal"), opt.get("outcomeLabel"))
            normalize_option(opt, qid=qid, dim=dim)
            after = (opt.get("signalTier"), opt.get("outcomeSignal"), opt.get("outcomeLabel"))
            if before != after:
                changed = True

    if changed:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return changed

def main():
    if not ASSESS_DIR.exists():
        raise SystemExit(f"❌ Missing folder: {ASSESS_DIR}")

    files = sorted(ASSESS_DIR.glob("*.json"))
    if not files:
        raise SystemExit(f"❌ No json files found in {ASSESS_DIR}")

    touched = []
    for f in files:
        if normalize_file(f):
            touched.append(f.name)

    print("✅ Done.")
    if touched:
        print("Updated files:")
        for n in touched:
            print(" -", n)
    else:
        print("No changes needed.")

if __name__ == "__main__":
    main()

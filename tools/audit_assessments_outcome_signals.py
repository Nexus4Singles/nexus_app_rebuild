import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ASSESS_DIR = Path("assets/config/assessments")
TOKEN_RE = re.compile(r"^[a-z0-9_]+$")

def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def main():
    if not ASSESS_DIR.exists():
        raise SystemExit(f"❌ Missing folder: {ASSESS_DIR} (run from repo root)")

    files = sorted(ASSESS_DIR.glob("*.json"))
    if not files:
        raise SystemExit(f"❌ No JSON files in {ASSESS_DIR}")

    overall_bad = 0
    overall_restoration = 0

    for path in files:
        data = load(path)
        questions = data.get("questions", [])
        print(f"\n==== {path.name} ====")

        # Collect outcomeSignal tokens to detect duplicates in the file
        tokens = []
        bad_rows = []
        restoration_rows = []

        for qi, q in enumerate(questions):
            qid = (q.get("id") or "").strip() or f"q{qi+1}"
            dim = (q.get("dimension") or "").strip()
            opts = q.get("options", [])

            for oi, opt in enumerate(opts):
                tier = (opt.get("signalTier") or "").strip()
                sig = (opt.get("outcomeSignal") or "").strip()
                lbl = (opt.get("outcomeLabel") or "").strip()
                if sig:
                    tokens.append(sig)
                if sig and not TOKEN_RE.fullmatch(sig):
                    bad_rows.append((qid, dim, tier, sig))
                if tier.upper() == "RESTORATION":
                    restoration_rows.append((qid, dim, sig, opt.get("text", "")))

        # Print bad outcomeSignal lines
        if bad_rows:
            print("BAD outcomeSignal (must be snake_case token):")
            for (qid, dim, tier, sig) in bad_rows[:80]:
                print(f" - {qid} [{dim}] tier={tier} outcomeSignal={sig}")
        else:
            print("✅ No bad outcomeSignal tokens found.")

        # Print restoration tiers
        if restoration_rows:
            print("⚠️ Found RESTORATION tiers (should map to DEVELOPING):")
            for (qid, dim, sig, text) in restoration_rows[:80]:
                print(f" - {qid} [{dim}] outcomeSignal={sig} optionText={text}")
        else:
            print("✅ No RESTORATION tiers found.")

        # Token collisions
        counts = Counter(tokens)
        dups = [t for t, c in counts.items() if c > 1]
        if dups:
            print("⚠️ Duplicate outcomeSignal tokens within file:")
            for t in dups[:80]:
                print(f" - {t} (x{counts[t]})")
        else:
            print("✅ No duplicate outcomeSignal tokens within file.")

        # Per-question summary
        print("\n-- Question summaries --")
        for qi, q in enumerate(questions):
            qid = (q.get("id") or "").strip() or f"q{qi+1}"
            title = (q.get("title") or q.get("prompt") or "").strip()
            dim = (q.get("dimension") or "").strip()
            opts = q.get("options", [])

            combos = defaultdict(int)
            for opt in opts:
                tier = (opt.get("signalTier") or "").strip()
                sig = (opt.get("outcomeSignal") or "").strip()
                lbl = (opt.get("outcomeLabel") or "").strip()
                combos[(tier, sig, lbl)] += 1

            print(f"\n[{qid}] {dim} :: {title[:80]}")
            for (tier, sig, lbl), c in combos.items():
                show_lbl = f" | label='{lbl[:60]}'" if lbl else ""
                print(f"  - {tier:12} {sig}{show_lbl}  (x{c})")

        overall_bad += len(bad_rows)
        overall_restoration += len(restoration_rows)

    print("\n========================")
    if overall_bad == 0:
        print("✅ GLOBAL: No bad outcomeSignal tokens across all files.")
    else:
        print(f"❌ GLOBAL: Found {overall_bad} bad outcomeSignal entries.")

    if overall_restoration == 0:
        print("✅ GLOBAL: No RESTORATION tiers across all files.")
    else:
        print(f"⚠️ GLOBAL: Found {overall_restoration} RESTORATION tier entries.")

if __name__ == "__main__":
    main()

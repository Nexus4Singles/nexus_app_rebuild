import json, re, glob, shutil
from datetime import datetime
from pathlib import Path

BASE = Path("assets/config/journeys")

FILES = [
    BASE / "journeys_single_never_married.v4.foundations.json",
    BASE / "journeys_divorced_widowed.v4.foundations.json",
    BASE / "journeys_married.v3.json",
]

def split_options(raw):
    if raw is None:
        return []
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    s = str(raw).strip()
    if not s:
        return []

    if "|" in s:
        parts = [p.strip() for p in s.split("|")]
        return [p for p in parts if p]

    if "\n" in s:
        parts = [p.strip() for p in s.split("\n")]
        return [p for p in parts if p]

    return [s]

def infer_ui(session):
    ui = (session.get("responseType") or session.get("responseUX") or "").lower()

    if "scale_3" in ui or "3-point" in ui or ("low" in ui and "neutral" in ui and "high" in ui):
        return "scale_3"

    if "multi" in ui:
        return "multi_select"

    if "single select + single select" in ui:
        return "single_select_pair"

    if "single" in ui:
        return "single_select"

    if "reflection" in ui or "journal" in ui or "text" in ui:
        return "text"

    return "text"

def normalize_session_steps(product_id, session):
    if session.get("steps") not in (None, []):
        for st in session.get("steps", []):
            if st.get("inferTags") is None:
                st["inferTags"] = []
        return session

    prompt = session.get("prompt")
    options = split_options(session.get("options"))
    ui = infer_ui(session)

    step = {
        "stepId": "pulse",
        "title": session.get("title") or f"Session {session.get('sessionNumber','')}",
        "contentType": "reflection",
        "content": prompt or "",
        "responseType": session.get("responseType"),
        "ui": ui,
        "options": options if options else None,
        "storeKey": f"journey.{product_id}.s{session.get('sessionNumber')}.pulse",
        "validation": {"required": True},
        "inferTags": [],
    }

    step = {k:v for k,v in step.items() if v is not None}

    session["steps"] = [step]
    return session

def normalize_product(p):
    pid = p.get("productId") or p.get("id") or ""
    p["productId"] = pid
    p["title"] = p.get("title") or p.get("productName")
    p["subtitle"] = p.get("subtitle") or p.get("preview")
    return p

def run():
    for f in FILES:
        if not f.exists():
            print(f"❌ Missing file: {f}")
            continue

        bak = f.with_suffix(f.suffix + ".bak")
        shutil.copy2(f, bak)

        data = json.loads(f.read_text())

        products = data.get("products", [])
        for p in products:
            p = normalize_product(p)
            sessions = p.get("sessions", [])
            for s in sessions:
                normalize_session_steps(p["productId"], s)

        f.write_text(json.dumps(data, indent=2, ensure_ascii=False))
        print(f"✅ Normalized: {f} (backup: {bak})")

if __name__ == "__main__":
    run()

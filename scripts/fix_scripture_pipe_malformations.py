import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET_DIR = ROOT / "assets" / "config" / "journeys"

# Matches common Bible reference forms like:
# Genesis 37:35, Psalm 23:4, 1 Thessalonians 4:13-14, Song of Solomon 2:1
BOOK = r"(?:[1-3]\s+)?(?:[A-Z][a-z]+(?:\s+(?:of|the))?\s*){1,4}"
REF = rf"(?P<ref>{BOOK}\d+:\d+(?:-\d+)?(?:,\s*\d+(?::\d+)?(?:-\d+)?)?)"

# Pattern A: Parenthesized malformed citation: (Ref|anything)
PAREN_PATTERN = re.compile(rf"\(({REF})\|[^)]*\)")

# Pattern B: Bare malformed citation: Ref|anything
# Conservative stop: stop before sentence punctuation, close paren, or line break
BARE_PATTERN = re.compile(rf"{REF}\|[^)\n\r\.\!\?]*")


def normalize_text(text: str) -> tuple[str, int]:
    changed = 0

    def repl_paren(m: re.Match) -> str:
        nonlocal changed
        changed += 1
        ref = m.group("ref").strip()
        return f"({ref})"

    updated = PAREN_PATTERN.sub(repl_paren, text)

    def repl_bare(m: re.Match) -> str:
        nonlocal changed
        changed += 1
        ref = m.group("ref").strip()
        return ref

    updated2 = BARE_PATTERN.sub(repl_bare, updated)
    return updated2, changed


def walk_and_fix(node):
    changes = 0
    if isinstance(node, dict):
        for k, v in node.items():
            nv, c = walk_and_fix(v)
            node[k] = nv
            changes += c
        return node, changes
    if isinstance(node, list):
        out = []
        for item in node:
            ni, c = walk_and_fix(item)
            out.append(ni)
            changes += c
        return out, changes
    if isinstance(node, str):
        return normalize_text(node)
    return node, 0


def main():
    total_files = 0
    touched_files = 0
    total_replacements = 0

    for path in sorted(TARGET_DIR.rglob("*.json")):
        total_files += 1
        original_text = path.read_text(encoding="utf-8")
        data = json.loads(original_text)

        updated_data, replacements = walk_and_fix(data)
        if replacements > 0:
            touched_files += 1
            total_replacements += replacements
            path.write_text(
                json.dumps(updated_data, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    print(f"Scanned files: {total_files}")
    print(f"Touched files: {touched_files}")
    print(f"Replacements: {total_replacements}")


if __name__ == "__main__":
    main()

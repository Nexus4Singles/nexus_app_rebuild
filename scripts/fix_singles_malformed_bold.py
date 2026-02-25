#!/usr/bin/env python3
import argparse
import glob
import json
from pathlib import Path

SINGLES_GLOB = "assets/config/journeys/singles journeys/singles_journey_*.json"


def fix_line_unmatched_bold(line: str) -> tuple[str, bool]:
    marker_count = line.count("**")
    if marker_count % 2 == 0:
        return line, False

    stripped = line.strip()
    if not stripped:
        return line, False

    if stripped.startswith("**") and not stripped.endswith("**"):
        return line + "**", True

    if stripped.endswith("**") and not stripped.startswith("**"):
        idx = line.rfind("**")
        if idx >= 0:
            return line[:idx] + line[idx + 2 :], True

    return line + "**", True


def fix_string(value: str) -> tuple[str, int]:
    changed = 0
    out_lines = []
    for line in value.split("\n"):
        new_line, was_changed = fix_line_unmatched_bold(line)
        if was_changed:
            changed += 1
        out_lines.append(new_line)
    return "\n".join(out_lines), changed


def walk_and_fix(node):
    if isinstance(node, str):
        return fix_string(node)

    if isinstance(node, list):
        updated = []
        total_changes = 0
        for item in node:
            new_item, c = walk_and_fix(item)
            updated.append(new_item)
            total_changes += c
        return updated, total_changes

    if isinstance(node, dict):
        updated = {}
        total_changes = 0
        for key, value in node.items():
            new_value, c = walk_and_fix(value)
            updated[key] = new_value
            total_changes += c
        return updated, total_changes

    return node, 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Fix malformed ** markers in singles journey files")
    parser.add_argument("--write", action="store_true", help="Write fixes to disk")
    args = parser.parse_args()

    files = sorted(glob.glob(SINGLES_GLOB))
    print(f"Found {len(files)} singles journey files")

    total_files_changed = 0
    total_line_fixes = 0

    for file_path in files:
        path = Path(file_path)
        with path.open("r", encoding="utf-8") as f:
            data = json.load(f)

        updated, line_fix_count = walk_and_fix(data)

        if line_fix_count > 0:
            total_files_changed += 1
            total_line_fixes += line_fix_count
            print(f"- {path.name}: {line_fix_count} line fix(es)")

            if args.write:
                with path.open("w", encoding="utf-8") as f:
                    json.dump(updated, f, ensure_ascii=False, indent=2)
                    f.write("\n")

    mode = "WRITE" if args.write else "DRY-RUN"
    print(f"[{mode}] files changed: {total_files_changed}, line fixes: {total_line_fixes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

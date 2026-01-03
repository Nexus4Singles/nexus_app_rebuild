#!/usr/bin/env bash
set -euo pipefail

OUT="analysis_options.yaml"

cat > "$OUT" <<'YAML'
analyzer:
  exclude:
YAML

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^# ]] && continue
  printf "    - %s\n" "$line" >> "$OUT"
done < tool/excludes.txt

cat >> "$OUT" <<'YAML'

  errors:
    deprecated_member_use: ignore
    prefer_const_constructors: ignore
    prefer_const_literals_to_create_immutables: ignore
    prefer_const_declarations: ignore
    dangling_library_doc_comments: ignore
    unused_import: ignore
YAML

echo "Generated $OUT from tool/excludes.txt"

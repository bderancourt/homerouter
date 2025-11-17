#!/usr/bin/env bash
set -euo pipefail

# Prepend a YAML document-start marker '---' to the first line of
# any '*.yml' or '*.yaml' file that doesn't already begin with it.
# Usage: ./scripts/add_yaml_header.sh [root-dir]
# Default root-dir is the current directory.

ROOT_DIR="${1:-.}"

if ! command -v mktemp >/dev/null 2>&1; then
  echo "mktemp is required" >&2
  exit 2
fi

find "$ROOT_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) \
  -not -path '*/.*/*' -print0 | \
while IFS= read -r -d '' file; do
  # Read first line (handle empty files)
  first_line=$(sed -n '1p' "$file" || true)
  # Remove possible CR (Windows) suffix using shell substitution (no external printf)
  first_line_clean=${first_line//$'\r'/}

  # Skip vaulted files that begin with $ANSIBLE_VAULT
  case "$first_line_clean" in
    \$ANSIBLE_VAULT*)
      echo "SKIP (vaulted): $file"
      continue
      ;;
  esac

  if [ "${first_line_clean}" != '---' ]; then
    # Preserve original file mode
    orig_mode=$(stat -c '%a' "$file" 2>/dev/null || echo 0644)
    tmpfile=$(mktemp "${file}.XXXXXX")
    # Use a safe printf invocation with an explicit format token
    printf '%s\n' '---' > "$tmpfile"
    cat -- "$file" >> "$tmpfile"
    mv -- "$tmpfile" "$file"
    chmod "$orig_mode" "$file" || true
    echo "Prepended header: $file"
  else
    echo "OK: $file"
  fi
done

exit 0

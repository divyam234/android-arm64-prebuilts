#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/prebuilt-tree" >&2
  exit 2
fi

root="$1"
if [[ ! -d "$root" ]]; then
  echo "error: not a directory: $root" >&2
  exit 2
fi

bad=0
while IFS= read -r -d '' f; do
  desc="$(file -b "$f" 2>/dev/null || true)"
  case "$desc" in
    *ELF*|*executable*|*shared\ object*)
      if [[ "$desc" == *x86-64* || "$desc" == *Intel\ 80386* ]]; then
        printf 'X86 HOST BINARY: %s: %s\n' "$f" "$desc"
        bad=1
      fi
      ;;
  esac
done < <(find "$root" -type f -print0)

if (( bad )); then
  echo "error: x86 host binaries found" >&2
  exit 1
fi

echo "OK: no x86 ELF host binaries found in $root"

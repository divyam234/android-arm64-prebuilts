#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
threshold_mb="${LFS_THRESHOLD_MB:-90}"
threshold=$((threshold_mb * 1024 * 1024))

cd "$root"
git lfs install --local >/dev/null

found=0
while IFS= read -r -d '' file; do
  size=$(stat -c %s "$file")
  if (( size >= threshold )); then
    rel="${file#./}"
    echo "LFS: $rel ($((size / 1024 / 1024)) MiB)"
    git lfs track "$rel" >/dev/null
    found=1
  fi
done < <(find ./prebuilts -type f -print0 2>/dev/null || true)

if (( found == 0 )); then
  echo "No files >= ${threshold_mb} MiB found under prebuilts/."
else
  echo "Updated .gitattributes. Review it, then git add .gitattributes prebuilts/."
fi

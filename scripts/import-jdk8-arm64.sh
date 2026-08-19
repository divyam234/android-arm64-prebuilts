#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/import-jdk8-arm64.sh /path/to/aarch64-jdk8 [source-id]

Copies a native Linux AArch64 JDK 8 distribution into:
  prebuilts/jdk/jdk8/linux-arm64

The optional source-id is recorded in SOURCE.txt (for example a vendor URL,
release tag, package version, or build identifier).
EOF
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="$(realpath "$1")"
source_id="${2:-unrecorded}"
dst="$root/prebuilts/jdk/jdk8/linux-arm64"

[[ -x "$src/bin/java" ]] || {
  echo "error: $src/bin/java is missing or not executable" >&2
  exit 1
}

case "$(file -b "$src/bin/java")" in
  *ARM\ aarch64*|*ARM64*|*aarch64*) ;;
  *)
    echo "error: source JDK is not Linux AArch64:" >&2
    file "$src/bin/java" >&2 || true
    exit 1
    ;;
esac

version="$($src/bin/java -version 2>&1 | head -n 1)"
if [[ "$version" != *'1.8.'* && "$version" != *'"8.'* ]]; then
  echo "error: source does not appear to be JDK 8: $version" >&2
  exit 1
fi

rm -rf "$dst"
mkdir -p "$dst"
cp -a "$src"/. "$dst"/

cat >"$dst/SOURCE.txt" <<EOF
source=$source_id
java_version=$version
host=aarch64-linux
imported_by=scripts/import-jdk8-arm64.sh
EOF

"$root/scripts/track-large-files.sh"

echo "Imported JDK 8 ARM64 into $dst"

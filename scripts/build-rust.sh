#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ANDROID_RUST_DIR=/path/to/toolchain/android_rust \
  RUST_STAGE0=/path/to/aarch64-stage0 \
  CLANG_PREBUILT=/path/to/aosp-arm64-clang \
  ./scripts/build-rust.sh

Optional:
  HOST_TRIPLE=aarch64-unknown-linux-gnu
  EXTRA_BUILD_ARGS='--host-only'
  PREBUILT_DEST=/custom/output/path

By default the completed toolchain is installed directly into:
  prebuilts/rust-toolchain/linux-arm64
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${ANDROID_RUST_DIR:?set ANDROID_RUST_DIR to toolchain/android_rust checkout}"
: "${RUST_STAGE0:?set RUST_STAGE0 to native ARM64 stage0 Rust prebuilt}"
: "${CLANG_PREBUILT:?set CLANG_PREBUILT to native AOSP ARM64 Clang prebuilt}"

ANDROID_RUST_DIR="$(realpath "$ANDROID_RUST_DIR")"
RUST_STAGE0="$(realpath "$RUST_STAGE0")"
CLANG_PREBUILT="$(realpath "$CLANG_PREBUILT")"

host="${HOST_TRIPLE:-aarch64-unknown-linux-gnu}"
dst="${PREBUILT_DEST:-$root/prebuilts/rust-toolchain/linux-arm64}"

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "error: this script is intended for native Linux ARM64" >&2; exit 2 ;;
esac

[[ -x "$RUST_STAGE0/bin/rustc" ]] || {
  echo "error: $RUST_STAGE0/bin/rustc is not executable" >&2
  exit 2
}

stage0_host="$($RUST_STAGE0/bin/rustc -vV | awk '/^host:/ {print $2}')"
[[ "$stage0_host" == "$host" ]] || {
  echo "error: stage0 Rust host is $stage0_host, expected $host" >&2
  exit 2
}

[[ -x "$CLANG_PREBUILT/bin/clang" ]] || {
  echo "error: $CLANG_PREBUILT/bin/clang is not executable" >&2
  exit 2
}

build_py="$ANDROID_RUST_DIR/tools/build.py"
[[ -f "$build_py" ]] || {
  echo "error: $build_py not found" >&2
  usage
  exit 2
}

# android_rust defines WORKSPACE_PATH as toolchain/android_rust/../.. and puts
# the unpacked package in <workspace>/out/package.
rust_workspace="$(realpath "$ANDROID_RUST_DIR/../..")"
package_dir="$rust_workspace/out/package"
dist_dir="$rust_workspace/dist-arm64-rust"

read -r -a extra <<<"${EXTRA_BUILD_ARGS:-}"

rm -rf "$dist_dir"
mkdir -p "$dist_dir"

set -x
python3 "$build_py" \
  --host "$host" \
  --rust-stage0-triple "$host" \
  --rust-prebuilt "$RUST_STAGE0" \
  --clang-prebuilt "$CLANG_PREBUILT" \
  --dist "$dist_dir" \
  --llvm-linkage shared \
  --lto thin \
  --cgu1 \
  "${extra[@]}"
set +x

[[ -x "$package_dir/bin/rustc" ]] || {
  echo "error: Android Rust build completed but package is missing: $package_dir/bin/rustc" >&2
  exit 1
}

file -b "$package_dir/bin/rustc" | grep -Eqi 'aarch64|ARM64|ARM aarch64' || {
  echo "error: generated rustc is not AArch64" >&2
  file "$package_dir/bin/rustc" >&2 || true
  exit 1
}

rm -rf "$dst"
mkdir -p "$(dirname "$dst")"
cp -a "$package_dir" "$dst"

"$root/scripts/check-prebuilt.sh" "$dst"
"$root/scripts/track-large-files.sh"

printf 'Installed Rust ARM64 prebuilt into %s\n' "$dst"

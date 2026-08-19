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
  OUT_DIR=/path/to/output
  EXTRA_BUILD_ARGS='--host-only'

This wrapper intentionally does not guess the Android Rust revision or Rust
version. Check out the revisions matching the ROM branch first.
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${ANDROID_RUST_DIR:?set ANDROID_RUST_DIR to toolchain/android_rust checkout}"
: "${RUST_STAGE0:?set RUST_STAGE0 to native ARM64 stage0 Rust prebuilt}"
: "${CLANG_PREBUILT:?set CLANG_PREBUILT to native AOSP ARM64 Clang prebuilt}"

host="${HOST_TRIPLE:-aarch64-unknown-linux-gnu}"
out="${OUT_DIR:-$root/out/rust}"
mkdir -p "$out"

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "error: this script is intended to produce native Linux ARM64 prebuilts" >&2; exit 2 ;;
esac

if [[ ! -x "$RUST_STAGE0/bin/rustc" ]]; then
  echo "error: $RUST_STAGE0/bin/rustc is not executable" >&2
  exit 2
fi

stage0_host="$($RUST_STAGE0/bin/rustc -vV | awk '/^host:/ {print $2}')"
if [[ "$stage0_host" != "$host" ]]; then
  echo "error: stage0 Rust host is $stage0_host, expected $host" >&2
  exit 2
fi

if [[ ! -x "$CLANG_PREBUILT/bin/clang" ]]; then
  echo "error: $CLANG_PREBUILT/bin/clang is not executable" >&2
  exit 2
fi

build_py="$ANDROID_RUST_DIR/tools/build.py"
if [[ ! -f "$build_py" ]]; then
  echo "error: $build_py not found" >&2
  usage
  exit 2
fi

read -r -a extra <<<"${EXTRA_BUILD_ARGS:-}"

set -x
python3 "$build_py" \
  --host "$host" \
  --rust-stage0-triple "$host" \
  --rust-prebuilt "$RUST_STAGE0" \
  --clang-prebuilt "$CLANG_PREBUILT" \
  --llvm-linkage shared \
  --lto thin \
  --cgu1 \
  "${extra[@]}"
set +x

cat <<EOF

Rust build completed.

Next steps:
  1. Locate the installed stage2 toolchain produced by android_rust.
  2. Verify native executables with: file <toolchain>/bin/rustc
  3. Import/package it into:
       $root/prebuilts/rust-toolchain/linux-arm64
  4. Record the exact android_rust/rustc commits before committing binaries.
EOF

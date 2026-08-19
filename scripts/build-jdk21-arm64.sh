#!/usr/bin/env bash
# Native Linux AArch64 variant of AOSP toolchain/jdk/build/build-openjdk21-linux.sh.
#
# Run this from an Android checkout that contains:
#   toolchain/jdk/jdk21
#   toolchain/jdk/build
#   prebuilts/clang/host/linux-arm64
#
# Required:
#   BOOT_JDK=/path/to/aarch64/boot-jdk
#
# Optional:
#   CLANG_REVISION=clang-r596125
#   JDK_DEPS_DIR=/path/to/arm64/debs
#   BUILD_NUMBER=0
#   USE_PGO=0|1
#
# Usage:
#   BOOT_JDK=/path/to/jdk ./scripts/build-jdk21-arm64.sh [-q] [-d DIST] BUILD_DIR

set -euo pipefail

prog="${0##*/}"

usage() {
  cat <<EOF
Usage:
  BOOT_JDK=/path/to/aarch64/jdk $prog [-q] [-d <dist_dir>] <build_dir>

Builds AOSP OpenJDK 21 natively for Linux AArch64 and optionally creates
jdk.zip and jdk-debuginfo.zip in <dist_dir>.
EOF
  exit 1
}

make_target_dir() {
  mkdir -p "$1"
  realpath "$1"
}

while getopts 'qd:' opt; do
  case "$opt" in
    d) dist_dir=$(make_target_dir "$OPTARG") ;;
    q) quiet=t ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -eq 1 ]] || usage

: "${BOOT_JDK:?Set BOOT_JDK to a native Linux AArch64 JDK usable for bootstrapping JDK21}"

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "error: this script is intended for a native aarch64 Linux host" >&2
  exit 1
fi

out_path=$(make_target_dir "$1")
sysroot="$out_path/sysroot"
build_dir="$out_path/build"

# ANDROID_BUILD_TOP is preferred. Otherwise assume this repository is checked
# out somewhere inside the Android source tree and use the caller's cwd.
top="${ANDROID_BUILD_TOP:-$(pwd)}"
top=$(realpath "$top")

clang_revision="${CLANG_REVISION:-clang-r596125}"
clang_bin="$top/prebuilts/clang/host/linux-arm64/$clang_revision/bin"
profdata="$top/toolchain/jdk/build/openjdk21.prof"
deps_dir="${JDK_DEPS_DIR:-$top/toolchain/jdk/deps-arm64}"
lib_triplet="aarch64-linux-gnu"

[[ -x "$clang_bin/clang" ]] || {
  echo "error: ARM64 AOSP clang not found at $clang_bin" >&2
  exit 1
}
[[ -x "$BOOT_JDK/bin/java" ]] || {
  echo "error: BOOT_JDK is not a JDK: $BOOT_JDK" >&2
  exit 1
}
[[ -d "$deps_dir" ]] || {
  echo "error: ARM64 JDK dependency directory not found: $deps_dir" >&2
  echo "Set JDK_DEPS_DIR to a directory containing the required arm64 .deb packages." >&2
  exit 1
}

file "$BOOT_JDK/bin/java" | grep -Eq 'ARM aarch64|ARM64|aarch64' || {
  echo "error: BOOT_JDK/bin/java is not an AArch64 executable" >&2
  file "$BOOT_JDK/bin/java" >&2 || true
  exit 1
}

unpack_dependencies() {
  local target_dir="$1"
  shift
  local ar="$clang_bin/llvm-ar"
  mkdir -p "$target_dir"

  local deb member link target relative_target_dir relative_target
  for deb in "$@"; do
    member=$("$ar" -t "$deb" | grep -m1 '^data\.tar' || true)
    case "$member" in
      data.tar.xz) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -Jx) ;;
      data.tar.bz2) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -jx) ;;
      data.tar.gz) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -zx) ;;
      data.tar.zst) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar --zstd -x) ;;
      *)
        echo "error: $deb does not contain a supported data.tar archive" >&2
        exit 1
        ;;
    esac
    [[ -n "${quiet:-}" ]] || echo "Unpacked $deb"
  done

  while IFS= read -r -d '' link; do
    target=$(readlink "$link")
    relative_target_dir=$(python3 -c 'import os.path,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$target_dir" "$(dirname "$link")")
    relative_target="${relative_target_dir}/${target#/}"
    ln -sfn "$relative_target" "$link"
  done < <(find "$target_dir" -type l -lname '/*' -print0)
}

mapfile -t debs < <(find "$deps_dir" -maxdepth 1 -type f -name '*.deb' -print | sort)
[[ ${#debs[@]} -gt 0 ]] || {
  echo "error: no .deb dependencies found in $deps_dir" >&2
  exit 1
}
rm -rf "$sysroot"
unpack_dependencies "$sysroot" "${debs[@]}"

# Debian multiarch directories must match the target architecture.
for required in \
  "$sysroot/usr/include" \
  "$sysroot/usr/lib/$lib_triplet"; do
  [[ -e "$required" ]] || {
    echo "error: ARM64 sysroot is missing $required" >&2
    exit 1
  }
done

# AOSP's checked-in openjdk21.prof is optional for the ARM64 bootstrap. Start
# without PGO unless explicitly enabled; once we have an ARM64 profile we can
# make it the default.
pgo_flags=()
if [[ "${USE_PGO:-0}" == "1" ]]; then
  [[ -f "$profdata" ]] || {
    echo "error: USE_PGO=1 but profile not found: $profdata" >&2
    exit 1
  }
  pgo_flags=("-fprofile-sample-use=$profdata")
fi

common_flags="--sysroot=$sysroot -fno-delete-null-pointer-checks -flto=full -gline-tables-only -fdebug-info-for-profiling -funique-internal-linkage-names"
if [[ ${#pgo_flags[@]} -gt 0 ]]; then
  common_flags+=" ${pgo_flags[*]}"
fi

mkdir -p "$build_dir"
[[ -n "${quiet:-}" ]] || set -x
(
  cd "$build_dir"
  bash +x "$top/toolchain/jdk/jdk21/configure" \
    "${quiet:+--quiet}" \
    --openjdk-target=aarch64-linux-gnu \
    --disable-full-docs \
    --disable-warnings-as-errors \
    --with-alsa-include="$sysroot/usr/include" \
    --with-alsa-lib="$sysroot/usr/lib/$lib_triplet" \
    --with-boot-jdk="$BOOT_JDK" \
    --with-cups-include="$sysroot/usr/include" \
    --with-sysroot="$sysroot" \
    --with-freetype=system \
    --with-freetype-lib="$sysroot/usr/lib/$lib_triplet" \
    --with-freetype-include="$sysroot/usr/include/freetype2" \
    --with-libpng=bundled \
    --with-native-debug-symbols=external \
    --with-stdc++lib=static \
    --with-toolchain-type=clang \
    --with-tools-dir="$clang_bin" \
    --with-version-pre= \
    --with-version-opt="${BUILD_NUMBER:-0}" \
    --with-vendor-version-string=Android_PDK \
    --with-zlib=bundled \
    --x-libraries="$sysroot/usr/lib/$lib_triplet" \
    --x-includes="$sysroot/usr/include" \
    --with-extra-cflags="$common_flags" \
    --with-extra-cxxflags="$common_flags" \
    --with-extra-ldflags="$common_flags -fuse-ld=lld" \
    AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
)

make_log_level=${quiet:+warn}
make -C "$build_dir" LOG="${make_log_level:-debug}" ${quiet:+-s} images

[[ -n "${dist_dir:-}" ]] || exit 0
rm -f "$dist_dir"/{jdk.zip,jdk-debuginfo.zip,build.log,configure.log}
(
  cd "$build_dir/images/jdk"
  zip -9rDy${quiet:+q} "$dist_dir/jdk.zip" . -x 'demo/*' -x 'man/*' -x '*.debuginfo'
  zip -9rDy${quiet:+q} "$dist_dir/jdk-debuginfo.zip" . -i '*.debuginfo'
)
[[ -e "$build_dir/build.log" ]] && cp "$build_dir/build.log" "$dist_dir/"
[[ -e "$build_dir/configure-support/config.log" ]] && cp "$build_dir/configure-support/config.log" "$dist_dir/"

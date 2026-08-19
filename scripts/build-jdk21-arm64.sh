#!/usr/bin/env bash
# Native Linux AArch64 variant of AOSP toolchain/jdk/build/build-openjdk21-linux.sh.
set -euo pipefail

prog="${0##*/}"

usage() {
  cat <<EOF
Usage:
  ANDROID_BUILD_TOP=/path/to/android \
  BOOT_JDK=/path/to/aarch64/jdk \
  $prog

Optional:
  CLANG_REVISION=clang-r596125
  JDK_DEPS_DIR=/path/to/arm64/debs
  BUILD_NUMBER=0
  USE_PGO=0|1
  BUILD_ROOT=/custom/build/workdir
  PREBUILT_DEST=/custom/output/path
  QUIET=1

By default the completed JDK is installed directly into:
  prebuilts/jdk/jdk21/linux-arm64
EOF
}

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${ANDROID_BUILD_TOP:?Set ANDROID_BUILD_TOP to the Android source checkout}"
: "${BOOT_JDK:?Set BOOT_JDK to a native Linux AArch64 boot JDK}"

top="$(realpath "$ANDROID_BUILD_TOP")"
BOOT_JDK="$(realpath "$BOOT_JDK")"
build_root="${BUILD_ROOT:-$root/.work/jdk21}"
dst="${PREBUILT_DEST:-$root/prebuilts/jdk/jdk21/linux-arm64}"
sysroot="$build_root/sysroot"
build_dir="$build_root/build"

case "$(uname -m)" in
  aarch64|arm64) ;;
  *) echo "error: this script is intended for native Linux ARM64" >&2; exit 1 ;;
esac

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
  exit 1
}

file -b "$BOOT_JDK/bin/java" | grep -Eqi 'aarch64|ARM64|ARM aarch64' || {
  echo "error: BOOT_JDK/bin/java is not AArch64" >&2
  file "$BOOT_JDK/bin/java" >&2 || true
  exit 1
}

mkdir -p "$build_root"
rm -rf "$sysroot" "$build_dir"
mkdir -p "$sysroot" "$build_dir"

unpack_dependencies() {
  local target_dir="$1"
  shift
  local ar="$clang_bin/llvm-ar"
  local deb member link target relative_target_dir relative_target

  for deb in "$@"; do
    member=$("$ar" -t "$deb" | grep -m1 '^data\.tar' || true)
    case "$member" in
      data.tar.xz) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -Jx) ;;
      data.tar.bz2) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -jx) ;;
      data.tar.gz) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar -zx) ;;
      data.tar.zst) "$ar" -p "$deb" "$member" | (cd "$target_dir" && tar --zstd -x) ;;
      *) echo "error: unsupported Debian archive: $deb" >&2; exit 1 ;;
    esac
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
  echo "error: no ARM64 .deb dependencies found in $deps_dir" >&2
  exit 1
}
unpack_dependencies "$sysroot" "${debs[@]}"

[[ -d "$sysroot/usr/lib/$lib_triplet" ]] || {
  echo "error: ARM64 sysroot is missing usr/lib/$lib_triplet" >&2
  exit 1
}

common_flags="--sysroot=$sysroot -fno-delete-null-pointer-checks -flto=full -gline-tables-only -fdebug-info-for-profiling -funique-internal-linkage-names"
if [[ "${USE_PGO:-0}" == "1" ]]; then
  [[ -f "$profdata" ]] || { echo "error: PGO profile not found: $profdata" >&2; exit 1; }
  common_flags+=" -fprofile-sample-use=$profdata"
fi

quiet_arg=()
[[ "${QUIET:-0}" == "1" ]] && quiet_arg=(--quiet)

(
  cd "$build_dir"
  bash +x "$top/toolchain/jdk/jdk21/configure" \
    "${quiet_arg[@]}" \
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

make -C "$build_dir" LOG=$([[ "${QUIET:-0}" == "1" ]] && echo warn || echo debug) images

image_dir="$build_dir/images/jdk"
[[ -x "$image_dir/bin/java" ]] || {
  echo "error: JDK build completed but $image_dir/bin/java is missing" >&2
  exit 1
}

file -b "$image_dir/bin/java" | grep -Eqi 'aarch64|ARM64|ARM aarch64' || {
  echo "error: generated JDK is not AArch64" >&2
  file "$image_dir/bin/java" >&2 || true
  exit 1
}

rm -rf "$dst"
mkdir -p "$(dirname "$dst")"
cp -a "$image_dir" "$dst"

"$root/scripts/check-prebuilt.sh" "$dst"
"$root/scripts/track-large-files.sh"

printf 'Installed JDK21 ARM64 prebuilt into %s\n' "$dst"

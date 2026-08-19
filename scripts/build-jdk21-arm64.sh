#!/usr/bin/env bash
# Populate the Linux ARM64 JDK 21 prebuilt directly in this repository.
#
# AOSP android-16.0.0_r4 ships JDK 21.0.4 for linux-x86. Google's public
# prebuilts repository does not ship linux-arm64 for that tag, so use the
# matching Temurin 21.0.4+7 AArch64 build as the public prebuilt.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dst="${PREBUILT_DEST:-$root/prebuilts/jdk/jdk21/linux-arm64}"
work="${WORK_DIR:-$root/.work/jdk21}"

jdk_version="${JDK_VERSION:-21.0.4}"
temurin_build="${TEMURIN_BUILD:-7}"
archive="OpenJDK21U-jdk_aarch64_linux_hotspot_${jdk_version}_${temurin_build}.tar.gz"
release_tag="jdk-${jdk_version}%2B${temurin_build}"
base_url="https://github.com/adoptium/temurin21-binaries/releases/download/${release_tag}"
url="${JDK_URL:-${base_url}/${archive}}"
checksum_url="${JDK_SHA256_URL:-${base_url}/${archive}.sha256.txt}"

case "$(uname -m)" in
  aarch64|arm64) ;;
  *)
    echo "error: this script must run on a Linux ARM64 host" >&2
    exit 1
    ;;
esac

for tool in curl tar file sha256sum awk; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "error: required tool is missing: $tool" >&2
    exit 1
  }
done

rm -rf "$work"
mkdir -p "$work/download" "$work/extract"
archive_path="$work/download/$archive"
checksum_path="$work/download/$archive.sha256.txt"

echo "Downloading JDK ${jdk_version}+${temurin_build} for Linux AArch64..."
curl --fail --location --retry 3 --output "$archive_path" "$url"
curl --fail --location --retry 3 --output "$checksum_path" "$checksum_url"

expected_sha="$(awk 'NF {print $1; exit}' "$checksum_path")"
[[ "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]] || {
  echo "error: invalid SHA-256 returned by $checksum_url" >&2
  exit 1
}
actual_sha="$(sha256sum "$archive_path" | awk '{print $1}')"
[[ "$actual_sha" == "$expected_sha" ]] || {
  echo "error: SHA-256 mismatch for $archive" >&2
  echo "expected: $expected_sha" >&2
  echo "actual:   $actual_sha" >&2
  exit 1
}

tar -xzf "$archive_path" -C "$work/extract"
mapfile -t roots < <(find "$work/extract" -mindepth 1 -maxdepth 1 -type d -print)
[[ ${#roots[@]} -eq 1 ]] || {
  echo "error: expected exactly one JDK directory in archive" >&2
  exit 1
}
src="${roots[0]}"

[[ -x "$src/bin/java" ]] || {
  echo "error: downloaded archive does not contain bin/java" >&2
  exit 1
}
[[ -f "$src/release" ]] || {
  echo "error: downloaded archive does not contain JDK release metadata" >&2
  exit 1
}

java_file="$(file -b "$src/bin/java")"
case "$java_file" in
  *aarch64*|*AArch64*|*ARM64*|*ARM\ aarch64*) ;;
  *)
    echo "error: downloaded java executable is not AArch64: $java_file" >&2
    exit 1
    ;;
esac

# Do not execute the downloaded binary here. Generic glibc binaries cannot be
# executed directly on stock NixOS because /lib/ld-linux-aarch64.so.1 is a stub.
# The JDK's own release metadata is enough to validate version and architecture.
release_java_version="$(awk -F= '$1 == "JAVA_VERSION" {gsub(/"/, "", $2); print $2; exit}' "$src/release")"
release_os_arch="$(awk -F= '$1 == "OS_ARCH" {gsub(/"/, "", $2); print $2; exit}' "$src/release")"

[[ "$release_java_version" == "$jdk_version" ]] || {
  echo "error: expected JDK $jdk_version to match android-16.0.0_r4, got: $release_java_version" >&2
  exit 1
}
case "$release_os_arch" in
  aarch64|arm64) ;;
  *)
    echo "error: JDK release metadata reports unexpected OS_ARCH=$release_os_arch" >&2
    exit 1
    ;;
esac

rm -rf "$dst"
mkdir -p "$(dirname "$dst")"
cp -a "$src" "$dst"

touch "$dst/MODULE_LICENSE_GPL"
cat >"$dst/SOURCE.txt" <<EOF
baseline=refs/tags/android-16.0.0_r4
baseline_aosp_java_version=21.0.4
source=Eclipse Adoptium Temurin
source_url=$url
source_sha256=$actual_sha
java_version=$release_java_version
host=aarch64-linux
imported_by=scripts/build-jdk21-arm64.sh
EOF

"$root/scripts/check-prebuilt.sh" "$dst"
"$root/scripts/track-large-files.sh"

printf 'Installed JDK21 ARM64 prebuilt into %s\n' "$dst"
printf 'Java version: %s\n' "$release_java_version"
printf 'Architecture: %s\n' "$release_os_arch"

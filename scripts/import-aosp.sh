#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$root/.tmp/imports"
mkdir -p "$work"

import_repo() {
  local name="$1" repo="$2" ref="$3" commit="$4" dest="$5"
  local src="$work/$name"

  rm -rf "$src"
  git clone --no-tags --filter=blob:none --branch "$ref" "$repo" "$src"
  git -C "$src" checkout --detach "$commit"
  rm -rf "$root/$dest"
  mkdir -p "$(dirname "$root/$dest")"
  cp -a "$src" "$root/$dest"
  rm -rf "$root/$dest/.git"

  cat >"$root/$dest/SOURCE.toml" <<EOF
name = "$name"
repo = "$repo"
ref = "$ref"
commit = "$commit"
imported_as = "$dest"
EOF
}

import_repo clang \
  https://android.googlesource.com/platform/prebuilts/clang/host/linux-arm64 \
  mirror-goog-main-prebuilts \
  1ab4a0aa701ef64db8a6e08a5995a369c008f600 \
  prebuilts/clang/host/linux-arm64

import_repo go \
  https://android.googlesource.com/platform/prebuilts/go/linux-arm64 \
  mirror-goog-llvm-r596125-release \
  85088d1ab9a678cc8531f9cc05de9fa802f91c58 \
  prebuilts/go/linux-arm64

import_repo cmake \
  https://android.googlesource.com/platform/prebuilts/cmake/linux-arm64 \
  mirror-goog-main-prebuilts \
  20526d417b6ca38b24bd4094eaaf528e2e4fb9e9 \
  prebuilts/cmake/linux-arm64

import_repo ninja \
  https://android.googlesource.com/platform/prebuilts/ninja/linux-arm64 \
  mirror-goog-main-prebuilts \
  f5f1d6a3c3d46d64ec9d2a3f9535a01c7ec71168 \
  prebuilts/ninja/linux-arm64

import_repo python \
  https://android.googlesource.com/platform/prebuilts/python/linux-arm64 \
  mirror-goog-llvm-r596125-release \
  e771c72074e9b17b6ccf15f8eee2755cac20dc27 \
  prebuilts/python/linux-arm64

import_repo build-tools \
  https://android.googlesource.com/platform/prebuilts/build-tools \
  mirror-goog-main-prebuilts \
  d95cf4dae352be7875dc4b473adc24fdce613078 \
  prebuilts/build-tools

printf '%s\n' "Imported populated AOSP Linux ARM64 prebuilts. Rust and JDK21 are intentionally handled by build scripts."

#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AOSP_TAG="${AOSP_TAG:-android-16.0.0_r4}"
AOSP_TAG_REF="refs/tags/${AOSP_TAG}"
lock="$root/revisions.lock"
manifest="$root/manifests/axion-arm64-prebuilts.xml"

aosp="https://android.googlesource.com"

resolve() {
  local repo="$1" ref="$2" sha
  sha="$(git ls-remote "$repo" "$ref" | awk 'NR==1 {sha=$1} END {print sha}')"
  if [[ -z "$sha" ]]; then
    echo "error: unable to resolve $repo $ref" >&2
    exit 1
  fi
  printf '%s' "$sha"
}

gitiles_text() {
  local repo_path="$1" ref="$2" file="$3"
  curl -fsSL "$aosp/$repo_path/+/$ref/$file?format=TEXT" | base64 -d
}

gitiles_tree_names() {
  local repo_path="$1" ref="$2" dir="$3"
  curl -fsSL "$aosp/$repo_path/+/$ref/$dir?format=JSON" \
    | tail -n +2 \
    | jq -r '.entries[].name'
}

find_branch_with_path() {
  local repo_url="$1" repo_path="$2" wanted_path="$3"
  local sha ref
  while read -r sha ref; do
    [[ -n "$sha" ]] || continue
    if curl -fsSL "$aosp/$repo_path/+/$sha/$wanted_path?format=JSON" >/dev/null 2>&1; then
      printf '%s %s\n' "$ref" "$sha"
      return 0
    fi
  done < <(git ls-remote --heads "$repo_url")
  return 1
}

find_go_branch_with_version() {
  local wanted="$1" repo_url="$aosp/platform/prebuilts/go/linux-arm64"
  local sha ref version
  while read -r sha ref; do
    [[ -n "$sha" ]] || continue
    version="$(gitiles_text platform/prebuilts/go/linux-arm64 "$sha" VERSION 2>/dev/null \
      | awk 'NR==1 {first=$0} END {print first}' || true)"
    if [[ "$version" == "$wanted" ]]; then
      printf '%s %s\n' "$ref" "$sha"
      return 0
    fi
  done < <(git ls-remote --heads "$repo_url")
  return 1
}

manifest_repo="$aosp/platform/manifest"
manifest_sha="$(resolve "$manifest_repo" "$AOSP_TAG_REF")"

# Exact tagged compatibility anchors.
clang_x86_repo="$aosp/platform/prebuilts/clang/host/linux-x86"
cmake_x86_repo="$aosp/platform/prebuilts/cmake/linux-x86"
go_x86_repo="$aosp/platform/prebuilts/go/linux-x86"
build_tools_repo="$aosp/platform/prebuilts/build-tools"
jdk8_repo="$aosp/platform/prebuilts/jdk/jdk8"
jdk21_repo="$aosp/platform/prebuilts/jdk/jdk21"

clang_x86_tag_sha="$(resolve "$clang_x86_repo" "$AOSP_TAG_REF")"
cmake_x86_tag_sha="$(resolve "$cmake_x86_repo" "$AOSP_TAG_REF")"
go_x86_tag_sha="$(resolve "$go_x86_repo" "$AOSP_TAG_REF")"
build_tools_tag_sha="$(resolve "$build_tools_repo" "$AOSP_TAG_REF")"
jdk8_tag_sha="$(resolve "$jdk8_repo" "$AOSP_TAG_REF")"
jdk21_tag_sha="$(resolve "$jdk21_repo" "$AOSP_TAG_REF")"

# Detect the exact versions selected by the Android tag itself.
clang_version="$(gitiles_text platform/build/soong "$AOSP_TAG_REF" cc/config/global.go \
  | awk -F'"' '/ClangDefaultVersion[[:space:]]*=/ && !found {value=$2; found=1} END {print value}')"
if [[ -z "$clang_version" ]]; then
  echo "error: could not detect ClangDefaultVersion from $AOSP_TAG" >&2
  exit 1
fi

go_version="$(gitiles_text platform/prebuilts/go/linux-x86 "$AOSP_TAG_REF" VERSION \
  | awk 'NR==1 {first=$0} END {print first}')"
if [[ -z "$go_version" ]]; then
  echo "error: could not detect Go version from $AOSP_TAG" >&2
  exit 1
fi

cmake_dir="$(gitiles_tree_names platform/prebuilts/cmake/linux-x86 "$AOSP_TAG_REF" share \
  | grep '^cmake-[0-9]' | sort -V | tail -n1)"
cmake_version="${cmake_dir#cmake-}"
if [[ -z "$cmake_version" || "$cmake_version" == "$cmake_dir" ]]; then
  echo "error: could not detect CMake version from $AOSP_TAG" >&2
  exit 1
fi

# Look for the exact same tool generation in Google's standalone ARM64 repos.
clang_arm64_repo="$aosp/platform/prebuilts/clang/host/linux-arm64"
go_arm64_repo="$aosp/platform/prebuilts/go/linux-arm64"
cmake_arm64_repo="$aosp/platform/prebuilts/cmake/linux-arm64"

clang_match_ref=""
clang_match_sha=""
if match="$(find_branch_with_path "$clang_arm64_repo" platform/prebuilts/clang/host/linux-arm64 "$clang_version")"; then
  read -r clang_match_ref clang_match_sha <<<"$match"
fi

go_match_ref=""
go_match_sha=""
if match="$(find_go_branch_with_version "$go_version")"; then
  read -r go_match_ref go_match_sha <<<"$match"
fi

cmake_match_ref=""
cmake_match_sha=""
if match="$(find_branch_with_path "$cmake_arm64_repo" platform/prebuilts/cmake/linux-arm64 "share/cmake-$cmake_version")"; then
  read -r cmake_match_ref cmake_match_sha <<<"$match"
fi

clang_status="build-required"
go_status="build-required"
cmake_status="build-required"
[[ -n "$clang_match_sha" ]] && clang_status="aosp-exact"
[[ -n "$go_match_sha" ]] && go_status="aosp-exact"
[[ -n "$cmake_match_sha" ]] && cmake_status="aosp-exact"

cat >"$lock" <<EOF
AOSP_TAG=$AOSP_TAG
AOSP_TAG_REF=$AOSP_TAG_REF
AOSP_MANIFEST_SHA=$manifest_sha

CLANG_VERSION=$clang_version
CLANG_X86_TAG_SHA=$clang_x86_tag_sha
CLANG_ARM64_STATUS=$clang_status
CLANG_ARM64_REF=$clang_match_ref
CLANG_ARM64_SHA=$clang_match_sha

GO_VERSION=$go_version
GO_X86_TAG_SHA=$go_x86_tag_sha
GO_ARM64_STATUS=$go_status
GO_ARM64_REF=$go_match_ref
GO_ARM64_SHA=$go_match_sha

CMAKE_VERSION=$cmake_version
CMAKE_X86_TAG_SHA=$cmake_x86_tag_sha
CMAKE_ARM64_STATUS=$cmake_status
CMAKE_ARM64_REF=$cmake_match_ref
CMAKE_ARM64_SHA=$cmake_match_sha

BUILD_TOOLS_TAG_SHA=$build_tools_tag_sha
JDK8_TAG_SHA=$jdk8_tag_sha
JDK21_TAG_SHA=$jdk21_tag_sha
EOF

cat >"$manifest" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Generated by scripts/update-revisions.sh for $AOSP_TAG_REF. -->
  <remote name="aosp-arm64" fetch="https://android.googlesource.com/" />
  <remote name="github-arm64" fetch="https://github.com/" />
EOF

if [[ "$clang_status" == "aosp-exact" ]]; then
  cat >>"$manifest" <<EOF

  <project path="prebuilts/clang/host/linux-arm64"
           name="platform/prebuilts/clang/host/linux-arm64"
           remote="aosp-arm64"
           revision="$clang_match_sha" />
EOF
fi

if [[ "$go_status" == "aosp-exact" ]]; then
  cat >>"$manifest" <<EOF

  <project path="prebuilts/go/linux-arm64"
           name="platform/prebuilts/go/linux-arm64"
           remote="aosp-arm64"
           revision="$go_match_sha" />
EOF
fi

if [[ "$cmake_status" == "aosp-exact" ]]; then
  cat >>"$manifest" <<EOF

  <project path="prebuilts/cmake/linux-arm64"
           name="platform/prebuilts/cmake/linux-arm64"
           remote="aosp-arm64"
           revision="$cmake_match_sha" />
EOF
fi

cat >>"$manifest" <<EOF

  <!--
    prebuilts/build-tools at $AOSP_TAG_REF already carries its tagged ARM64
    subtree, so keep the Android tag's own project instead of mixing in a
    newer mirror branch.

    Tools marked build-required in revisions.lock are provided by our
    monorepo at the exact Android-tag-compatible versions.
  -->
  <project path="prebuilts/arm64-host"
           name="divyam234/android-arm64-prebuilts"
           remote="github-arm64"
           revision="main">
EOF

if [[ "$clang_status" == "build-required" ]]; then
  cat >>"$manifest" <<'EOF'
    <linkfile src="prebuilts/clang/host/linux-arm64"
              dest="prebuilts/clang/host/linux-arm64" />
EOF
fi
if [[ "$go_status" == "build-required" ]]; then
  cat >>"$manifest" <<'EOF'
    <linkfile src="prebuilts/go/linux-arm64"
              dest="prebuilts/go/linux-arm64" />
EOF
fi
if [[ "$cmake_status" == "build-required" ]]; then
  cat >>"$manifest" <<'EOF'
    <linkfile src="prebuilts/cmake/linux-arm64"
              dest="prebuilts/cmake/linux-arm64" />
EOF
fi

cat >>"$manifest" <<'EOF'
    <linkfile src="prebuilts/rust-toolchain/linux-arm64"
              dest="prebuilts/rust-toolchain/linux-arm64" />
    <linkfile src="prebuilts/jdk/jdk8/linux-arm64"
              dest="prebuilts/jdk/jdk8/linux-arm64" />
    <linkfile src="prebuilts/jdk/jdk21/linux-arm64"
              dest="prebuilts/jdk/jdk21/linux-arm64" />
  </project>
</manifest>
EOF

printf 'Updated %s and %s\n' "$lock" "$manifest"
printf 'Base Android tag: %s (%s)\n' "$AOSP_TAG_REF" "$manifest_sha"
printf 'Clang %-14s %-18s %s\n' "$clang_version" "$clang_status" "${clang_match_sha:-not published for ARM64}"
printf 'Go    %-14s %-18s %s\n' "$go_version" "$go_status" "${go_match_sha:-not published for ARM64}"
printf 'CMake %-14s %-18s %s\n' "$cmake_version" "$cmake_status" "${cmake_match_sha:-not published for ARM64}"

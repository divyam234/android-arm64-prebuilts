# android-arm64-prebuilts

Linux ARM64 host prebuilts for building Android/AOSP-derived ROMs natively on AArch64 Linux hosts.

This repository stores the actual prebuilt trees in Git. Large binaries are tracked with Git LFS; GitHub Release assets are not used.

## Baseline

The default compatibility baseline is:

```text
refs/tags/android-16.0.0_r4
```

Run:

```bash
./scripts/update-revisions.sh
```

The resolver reads the Android tag itself, detects the exact Clang/Go/CMake versions selected by that release, checks Google's standalone ARM64 prebuilt repositories for an exact match, and writes the result to `revisions.lock`.

A newer ARM64 compiler/tool is never substituted silently.

For `android-16.0.0_r4`, the detected versions are currently:

```text
Clang  clang-r563880c
Go     go1.24.1
CMake  3.22
```

Google's current standalone ARM64 repositories do not publish those exact generations, so these three are marked `build-required` and are maintained here.

`prebuilts/build-tools` is different: the Android 16 r4 tagged repository already contains its ARM64 subtree, so use the tagged AOSP project directly rather than a newer mirror branch.

## Layout

```text
prebuilts/
├── clang/host/linux-arm64/
├── go/linux-arm64/
├── cmake/linux-arm64/
├── rust-toolchain/linux-arm64/
└── jdk/
    ├── jdk8/linux-arm64/
    └── jdk21/linux-arm64/
```

Only paths that need locally maintained exact-compatible ARM64 prebuilts are populated here. If Google later publishes an exact ARM64 match, the resolver can use that AOSP project instead.

## Git LFS

Large prebuilt binaries are committed through Git LFS. A build host cloning this repository must have Git LFS installed and fetch LFS objects:

```bash
git lfs install
git lfs pull
```

Before committing populated prebuilts, run:

```bash
./scripts/track-large-files.sh
```

## Rust

Rust is built with Google's Android Rust toolchain pipeline from `toolchain/android_rust`, using a native `aarch64-unknown-linux-gnu` bootstrap compiler and the exact Clang generation required by the selected Android baseline.

See `scripts/build-rust.sh`.

## JDK 8

JDK8 is imported from a pinned native Linux AArch64 JDK8 distribution and validated before installation into:

```text
prebuilts/jdk/jdk8/linux-arm64/
```

See `scripts/import-jdk8-arm64.sh`.

## JDK 21

JDK21 is produced from Google's published OpenJDK build sources and build logic in `toolchain/jdk/build`, adapted for a native AArch64 Linux host.

The resulting distribution goes under:

```text
prebuilts/jdk/jdk21/linux-arm64/
```

See `scripts/build-jdk21-arm64.sh`.

## Manifest integration

`scripts/update-revisions.sh` regenerates:

```text
manifests/axion-arm64-prebuilts.xml
```

Exact Google ARM64 matches are pinned by SHA. Missing exact matches are linked from this monorepo into the standard AOSP paths with `linkfile` entries.

## Goal

The final Android tree should use tool versions compatible with the selected Android release while running all required host build tools natively on Linux ARM64, without x86 emulation.

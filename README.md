# android-arm64-prebuilts

Linux ARM64 host prebuilts needed to build Android/AOSP-derived ROMs natively on AArch64 Linux hosts.

This repository stores the actual prebuilts in Git. Large binaries are tracked with Git LFS; GitHub Release assets are not used.

## Baseline

The default Android compatibility baseline is:

```text
refs/tags/android-16.0.0_r4
```

Run:

```bash
./scripts/update-revisions.sh
```

to refresh the pinned AOSP ARM64 tool revisions in `revisions.lock` and regenerate the Axion local manifest.

## What comes directly from AOSP

These are not mirrored here:

```text
prebuilts/clang/host/linux-arm64
prebuilts/go/linux-arm64
prebuilts/cmake/linux-arm64
prebuilts/ninja/linux-arm64
prebuilts/python/linux-arm64
prebuilts/build-tools
```

The generated manifest pulls them directly from Google.

## What this repo provides

Only these generated paths are owned here:

```text
prebuilts/
├── rust-toolchain/
│   └── linux-arm64/
└── jdk/
    ├── jdk8/
    │   └── linux-arm64/
    └── jdk21/
        └── linux-arm64/
```

The directories are created only when the corresponding prebuilt is populated.

## Rust

Rust uses Google's `toolchain/android_rust` build pipeline with an ARM64 stage0 compiler and AOSP ARM64 Clang.

```bash
ANDROID_RUST_DIR=/path/to/toolchain/android_rust \
RUST_STAGE0=/path/to/aarch64-stage0 \
CLANG_PREBUILT=/path/to/aosp-arm64-clang \
./scripts/build-rust.sh
```

The completed package is installed automatically into:

```text
prebuilts/rust-toolchain/linux-arm64/
```

## JDK 8

JDK8 currently uses a validated native AArch64 import flow:

```bash
./scripts/import-jdk8-arm64.sh /path/to/jdk8-aarch64 <source-id>
```

It installs directly into:

```text
prebuilts/jdk/jdk8/linux-arm64/
```

## JDK 21

Android 16 r4 ships Java **21.0.4** for its Linux x86 host prebuilt. Google's public Android 16 JDK21 tree does not include a Linux ARM64 directory, so this repository uses the matching public Temurin **21.0.4+7** AArch64 JDK.

Just run:

```bash
./scripts/build-jdk21-arm64.sh
```

The script automatically:

- downloads the Linux AArch64 JDK,
- downloads and verifies its SHA-256,
- verifies `bin/java` is AArch64,
- verifies the Java version is 21.0.4,
- installs it directly into `prebuilts/jdk/jdk21/linux-arm64/`,
- writes source metadata,
- checks for accidental x86 host binaries,
- enables Git LFS tracking for large files.

No Android checkout, boot JDK, Clang path, or output directory is required.

## Git LFS

Large generated files are tracked automatically by:

```bash
./scripts/track-large-files.sh
```

A checkout consuming this repository should have Git LFS installed:

```bash
git lfs install
git lfs pull
```

## Manifest integration

`manifests/axion-arm64-prebuilts.xml`:

1. pulls Google-maintained ARM64 host tools directly from AOSP;
2. clones this repository once;
3. exposes Rust, JDK8 and JDK21 at their normal Android paths with directory `linkfile` entries.

## Goal

The final Android source tree should run host build tools natively on Linux ARM64 without x86 emulation and without unnecessarily mirroring Google-maintained prebuilts.

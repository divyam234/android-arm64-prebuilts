# android-arm64-prebuilts

Linux ARM64 host prebuilts needed to build Android/AOSP-derived ROMs natively on AArch64 Linux hosts.

This repository stores only the prebuilts we actually need to provide ourselves. Google-maintained ARM64 host prebuilts are consumed directly from AOSP and are not mirrored here.

## Baseline

The default baseline is:

```text
refs/tags/android-16.0.0_r4
```

Run:

```bash
./scripts/update-revisions.sh
```

to resolve the current exact SHAs used by the generated manifest and write them to `revisions.lock`.

## What comes directly from AOSP

These are downloaded from Google's AOSP repositories directly:

```text
prebuilts/clang/host/linux-arm64
prebuilts/go/linux-arm64
prebuilts/cmake/linux-arm64
prebuilts/ninja/linux-arm64
prebuilts/python/linux-arm64
prebuilts/build-tools
```

We do not duplicate those trees in this repository.

## What this repository provides

Only:

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

The directories are intentionally absent until real prebuilts are generated or imported.

## Git LFS

Large binaries are stored in Git LFS rather than GitHub Release assets.

Before committing generated prebuilts:

```bash
./scripts/track-large-files.sh
git add .gitattributes prebuilts/
```

A build host should have Git LFS installed before `repo sync`.

## Rust

Rust is built with Google's Android Rust toolchain pipeline from `toolchain/android_rust`, using a native `aarch64-unknown-linux-gnu` stage0 compiler and AOSP's ARM64 Clang.

Use:

```text
scripts/build-rust.sh
```

The result is installed under:

```text
prebuilts/rust-toolchain/linux-arm64/
```

## JDK 8

JDK8 currently uses a validated native AArch64 import flow:

```bash
./scripts/import-jdk8-arm64.sh /path/to/jdk8-aarch64 <source-id>
```

The result is installed under:

```text
prebuilts/jdk/jdk8/linux-arm64/
```

## JDK 21

JDK21 is built from Google's published OpenJDK build sources and build logic in `toolchain/jdk/build`, adapted for native Linux AArch64.

Use:

```text
scripts/build-jdk21-arm64.sh
```

The result is installed under:

```text
prebuilts/jdk/jdk21/linux-arm64/
```

## Manifest integration

`manifests/axion-arm64-prebuilts.xml` does two things:

1. Pulls Clang, Go, CMake, Ninja, and Python directly from AOSP ARM64 repositories.
2. Clones this repository once and exposes only Rust, JDK8, and JDK21 at their normal AOSP paths using `linkfile` directory links.

## Goal

The final Android source tree should run all build-host tools natively on Linux ARM64 without x86 emulation while avoiding unnecessary copies of Google-maintained prebuilts.

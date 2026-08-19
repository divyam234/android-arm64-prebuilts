# android-arm64-prebuilts

Linux ARM64 host prebuilts missing from the Android/AOSP-derived trees we want to build natively on AArch64 Linux hosts.

This repository stores the actual prebuilt trees in Git. Large binaries are tracked with Git LFS; GitHub Release assets are not used.

## Scope

We only maintain prebuilts that are not already usable directly from AOSP:

```text
prebuilts/
├── rust-toolchain/
│   └── linux-arm64/
└── jdk/
    └── jdk21/
        └── linux-arm64/
```

Clang, Go, CMake, Ninja, Python and build-tools should be pulled directly from Google's AOSP ARM64 prebuilt repositories rather than mirrored here.

## Git LFS

Large prebuilt binaries are committed through Git LFS. A build host cloning this repository must have Git LFS installed and fetch LFS objects:

```bash
git lfs install
git lfs pull
```

Android `repo` users should also have Git LFS installed before syncing.

## Rust

Rust is built with Google's Android Rust toolchain pipeline from `toolchain/android_rust`, using a native `aarch64-unknown-linux-gnu` bootstrap compiler and AOSP's ARM64 Clang.

The resulting distribution is installed under:

```text
prebuilts/rust-toolchain/linux-arm64/
```

See `scripts/build-rust.sh`.

## JDK 21

JDK21 is produced from Google's published OpenJDK build sources and build script in `toolchain/jdk/build` and adapted for a native AArch64 Linux host.

The resulting distribution is installed under:

```text
prebuilts/jdk/jdk21/linux-arm64/
```

See `scripts/build-jdk21-arm64.sh`.

## AOSP ARM64 prebuilts

The Axion ARM64 manifest should fetch these directly from AOSP:

```text
platform/prebuilts/clang/host/linux-arm64
platform/prebuilts/go/linux-arm64
platform/prebuilts/cmake/linux-arm64
platform/prebuilts/ninja/linux-arm64
platform/prebuilts/python/linux-arm64
platform/prebuilts/build-tools
```

The exact revisions are recorded in `components.toml` and the sample manifest under `manifests/`.

## Goal

The final ARM64-host Android tree should be able to run all host build tools natively without x86 emulation.

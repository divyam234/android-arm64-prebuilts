# android-arm64-prebuilts

Linux ARM64 host prebuilts needed for building Android/AOSP-derived ROMs natively on AArch64 Linux hosts.

This repository stores only the prebuilts we need to maintain ourselves. Large files are tracked with Git LFS.

## Baseline

The default compatibility baseline is:

```text
refs/tags/android-16.0.0_r4
```

Run:

```bash
./scripts/update-revisions.sh
```

to refresh `revisions.lock` and regenerate the sample manifest.

## What comes directly from AOSP

Do not mirror these into this repository:

```text
prebuilts/clang/host/linux-arm64
prebuilts/go/linux-arm64
prebuilts/cmake/linux-arm64
prebuilts/ninja/linux-arm64
prebuilts/python/linux-arm64
prebuilts/build-tools
```

The generated Axion manifest pulls them from AOSP directly.

## What this repository owns

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

The directories are created automatically only when a real prebuilt is generated or imported.

## Automatic output

You do not need to provide an output directory for normal use.

Each script replaces and populates its standard AOSP-style destination automatically, verifies the resulting binaries are ARM64, and runs the Git LFS tracker afterward.

An optional `PREBUILT_DEST=/custom/path` override exists only for testing.

## Rust

Rust is built with Google's Android Rust toolchain pipeline from `toolchain/android_rust`, using a native `aarch64-unknown-linux-gnu` stage0 compiler and AOSP ARM64 Clang.

```bash
ANDROID_RUST_DIR=/path/to/android/toolchain/android_rust \
RUST_STAGE0=/path/to/aarch64-stage0 \
CLANG_PREBUILT=/path/to/aosp-arm64-clang \
./scripts/build-rust.sh
```

On success it automatically installs the generated package into:

```text
prebuilts/rust-toolchain/linux-arm64/
```

## JDK 8

JDK8 currently uses a validated native AArch64 import flow:

```bash
./scripts/import-jdk8-arm64.sh /path/to/jdk8-aarch64 <source-id>
```

It automatically replaces and populates:

```text
prebuilts/jdk/jdk8/linux-arm64/
```

## JDK 21

JDK21 is built from Google's OpenJDK source/build logic in `toolchain/jdk`, adapted for native Linux AArch64.

```bash
ANDROID_BUILD_TOP=/path/to/android \
BOOT_JDK=/path/to/aarch64/boot-jdk \
./scripts/build-jdk21-arm64.sh
```

The temporary build directory defaults to `.work/jdk21` and the completed JDK is automatically copied into:

```text
prebuilts/jdk/jdk21/linux-arm64/
```

Optional overrides include `BUILD_ROOT`, `JDK_DEPS_DIR`, `CLANG_REVISION`, and `PREBUILT_DEST`.

## Git LFS

Large generated files are tracked automatically by:

```bash
./scripts/track-large-files.sh
```

A checkout that consumes this repository should have Git LFS installed:

```bash
git lfs install
git lfs pull
```

## Manifest integration

`manifests/axion-arm64-prebuilts.xml`:

1. pulls Google-maintained ARM64 host prebuilts directly from AOSP;
2. clones this repository once;
3. exposes Rust, JDK8, and JDK21 at their normal AOSP paths with `linkfile` directory links.

## Goal

The final Android source tree should run all build-host tools natively on Linux ARM64 without x86 emulation and without duplicating Google-maintained prebuilts.

# android-arm64-prebuilts

AOSP-style Linux ARM64 host prebuilts collected for building Android/AOSP-derived ROMs natively on AArch64 Linux hosts.

This repository intentionally stores prebuilts directly in Git, mirroring Android source-tree paths rather than using GitHub Release assets.

## Layout

```text
prebuilts/
├── clang/host/linux-arm64/
├── go/linux-arm64/
├── cmake/linux-arm64/
├── ninja/linux-arm64/
├── python/linux-arm64/
├── build-tools/
├── rust-toolchain/linux-arm64/
└── jdk/
    └── jdk21/linux-arm64/
```

## Goals

- Provide native `linux-arm64` host tools for AOSP/Lineage/Axion builds.
- Preserve upstream AOSP directory layouts where practical.
- Pin the exact upstream revision used for each imported prebuilt.
- Build missing prebuilts, notably Rust and JDK21, reproducibly for ARM64.
- Avoid x86 emulation on ARM64 Android build hosts.

## Source policy

Imported Google/AOSP prebuilts retain their upstream license and metadata. Each imported component must include a `SOURCE.toml` recording its source repository, branch/ref, commit and import method.

Do not silently replace binaries with distro packages: every component in this repository should be traceable and reproducible.

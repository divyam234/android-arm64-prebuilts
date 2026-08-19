# Linux ARM64 Go prebuilt

This directory is populated only when Google does not publish an exact Linux ARM64 match for the Android baseline selected in `revisions.lock`.

For `android-16.0.0_r4`, the tagged x86 prebuilt is Go `go1.24.1`; Google's standalone Linux ARM64 Go repository currently publishes newer Go 1.25.x toolchains, so an exact-compatible ARM64 Go 1.24.1 prebuilt must be produced here.

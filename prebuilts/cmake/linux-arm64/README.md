# Linux ARM64 CMake prebuilt

This directory is populated only when Google does not publish an exact Linux ARM64 match for the Android baseline selected in `revisions.lock`.

For `android-16.0.0_r4`, the tagged x86 prebuilt is CMake `3.22`; Google's standalone Linux ARM64 CMake repository currently publishes CMake 4.1, so an exact-compatible ARM64 CMake 3.22 prebuilt must be produced here.

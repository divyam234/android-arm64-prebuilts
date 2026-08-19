# Linux ARM64 Clang prebuilt

This directory is populated only when Google does not publish an exact Linux ARM64 match for the Android baseline selected in `revisions.lock`.

For `android-16.0.0_r4`, Soong selects `clang-r563880c`; Google's standalone Linux ARM64 Clang repository does not currently publish that exact generation, so it must be built and packaged here rather than silently replaced with a newer compiler.

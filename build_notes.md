# Build Notes

## Android

Requires `ANDROID_HOME` set to the Android SDK:

```
export ANDROID_HOME=/home/lexmint/.kivyschool/android-sdk/
```

Wheels are built from `PyNucleantUI/` with `cibuildwheel`, targeting the AVD's
ABI (`cp313-android_x86_64` for the emulator, `cp313-android_arm64_v8a` for
real devices):

```
cd PyNucleantUI
cibuildwheel --only cp313-android_x86_64 --output-dir ../NucleantAppTest/wheelhouse
```

### Default: `VK_KHR_external_memory_fd`

No extra env var needed — this is the default zero-copy import path for the
Vulkan render target, matching Linux/Wayland. Real Android GPU drivers
generally support `VK_KHR_external_memory_fd` fine; use this build for real
devices.

### Opt-in: AHardwareBuffer

Some emulator configurations (gfxstream/ranchu's virtualized Vulkan driver)
don't expose `VK_KHR_external_memory_fd`, even with `hw.gpu.mode = host`. For
those, switch the import path to `AHardwareBuffer` at build time:

```
cd PyNucleantUI
NUCLEANT_ANDROID_USE_AHARDWAREBUFFER=1 cibuildwheel --only cp313-android_x86_64 --output-dir ../NucleantAppTest/wheelhouse
```

The env var must be set for the `cibuildwheel` invocation (it propagates to
the `swift build` calls for both `NucleantVulkan` and `NucleantThorVG` —
these two must agree, since `NucleantThorVG`'s import path calls straight
into `NucleantVulkan`'s `WgpuContext.Target.nativeAndroidHardwareBuffer()`).

**Never make this the default.** AHardwareBuffer is confirmed slow on real
hardware unless the `AHardwareBuffer_Desc.usage` flags are *exactly*
`AHARDWAREBUFFER_USAGE_GPU_SAMPLED_IMAGE | AHARDWAREBUFFER_USAGE_GPU_COLOR_OUTPUT`
— any other usage bit makes the allocator fall back to CPU-accessible
(linear) tiling instead of the GPU's native tiling, which is a large
performance regression. This is purely an emulator workaround; ship real
devices with the `fd` build.

After building the wheel, rebuild the app from `NucleantAppTest/`:

```
export ANDROID_API_LEVEL=28
NUCLEANT_BOOTSTRAP_AAR=$(find . -iname "*bootstrap*.aar" | head -1) uv run ksproject android build
uv run ksproject android run --name ksproject_default
```

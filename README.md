# Micromax IN Note 1 (`yogurt`) — DerpFest 17 / Android 17 Bring-up Archive

Complete source & patch archive for **DerpFest 17 (Android 17 / `lineage-24.0`, `cp2a`)** on **Micromax IN Note 1 (`yogurt`, E7746, MediaTek MT6768 Helio G85, Kernel 4.14.141)**.

## Device / Vendor / Kernel / Sepolicy / Camera Repositories
All custom/forked trees live under `bishalregmi105B` on GitHub:
- **Local Manifest**: [`manifests/yogurt.xml`](manifests/yogurt.xml)
- **Device Tree** (`seventeen`): `https://github.com/bishalregmi105B/android_device_micromax_yogurt`
- **Vendor Blobs** (`seventeen`): `https://github.com/bishalregmi105B/android_vendor_micromax_yogurt`
- **Kernel 4.14.141**: `https://github.com/bishalregmi105B/yogurt`
  - Branch `seventeen`: DerpFest 17 AOSP source kernel
  - Branch `coloros17`: ColorOS 17 EROFS + LZ4 + fscrypt kernel
- **MTK Sepolicy** (`seventeen`): `https://github.com/bishalregmi105B/android_device_mediatek_sepolicy_vndr`
- **Aperture Camera** (`seventeen`): `https://github.com/bishalregmi105B/android_packages_apps_Aperture`

## AOSP / DerpFest Tree Patches
- [`BASE_SHAS.txt`](BASE_SHAS.txt): Base commit SHAs and upstream remotes for every patched repository.
- [`patches/`](patches/): `git diff --binary` patches per repository (`frameworks/base`, `build/soong`, `system/core`, `system/bpf`, `vendor/lineage`, `bootable/recovery`, `packages/modules/Connectivity`, etc.).
- [`untracked/`](untracked/): New files added outside git history.
- [`apply_patches.sh`](apply_patches.sh): Applies all patches and copies untracked files onto a freshly synced DerpFest 17 tree.
- [`docs/`](docs/): Build verification notes (`BUILD_SUCCESS.txt`), migration/audit docs, install/restore guides, and SELinux CIL artifacts (`ci_artifacts/cil`).

## Quick Reproduction Steps
```bash
mkdir derpfest17 && cd derpfest17
repo init -u https://github.com/DerpFest-AOSP/android_manifest.git -b 17 --git-lfs
mkdir -p .repo/local_manifests
cp /path/to/yogurt-a17-rom-patches/manifests/yogurt.xml .repo/local_manifests/yogurt.xml
repo sync -c --no-clone-bundle --no-tags -j$(nproc)

# Apply AOSP/DerpFest patches & untracked files
chmod +x /path/to/yogurt-a17-rom-patches/apply_patches.sh
/path/to/yogurt-a17-rom-patches/apply_patches.sh "$(pwd)"

# Build
source build/envsetup.sh
lunch derp_yogurt-bp4a-userdebug
mka derp
```
*(Note: `prebuilts/clang/host/linux-x86/clang-r353983c` for kernel 4.14 and Google-presigned `PrebuiltGmsCore.apk` for `vendor/pixel/gms` are not stored in git due to binary size limits — fetch `clang-r353983c` and extract `PrebuiltGmsCore.apk` from `com.google.android.gmssystem.prodvic.apex` if building GMS.)*

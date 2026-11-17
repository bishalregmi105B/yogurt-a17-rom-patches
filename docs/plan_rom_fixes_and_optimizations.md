# DerpFest 17 (`yogurt` / Micromax IN Note 1) — Comprehensive Fix, Integrity, VoLTE & Performance Plan

This plan consolidates live ADB telemetry from connected device `8XT4Q8IZNB9XQGF6` (`4.14.141-yogurt-v1.x #8`, SELinux `Enforcing`, `user`/`release-keys`, `super` usage `3956.0 MiB / 4092.0 MiB`) with kernel, vendor, framework, and open-source custom ROM community findings.

---

## 1. Root Causes & Verified Fixes

### 1.1 Double Tap to Wake (DT2W) Broken
**Observed Root Causes:**
1. **Wrong kernel config:** `kernel/micromax/yogurt/drivers/input/touchscreen/mediatek/focaltech_touch_spi/focaltech_config.h` (line 157) hardcodes `#define FTS_GESTURE_EN 0`. Live `/proc` / `kernel_raw` confirms FocalTech SPI (`fts_ts`, `/dev/input/event2`) is the compiled touchscreen driver, with `fts_gesture_mode` present at `/sys/devices/platform/1100a000.spi0/spi_master/spi1/spi1.0/fts_gesture_mode`.
2. **Wrong keycode & keylayout:** `focaltech_gesture.c` (lines 40, 228–230) reports `KEY_GESTURE_U` (`KEY_U`) on double-tap while `fts_ts` (`dumpsys input`) binds `/system/usr/keylayout/Generic.kl`, which does not map `U` as `WAKE`.
3. **Wrong init target:** `device/micromax/yogurt/rootdir/etc/init.mt6768.rc` (lines 1021–1025) runs `exec /system/bin/sendevent /dev/input/event3 0 1 4|5` on virtual `mtk-tpd`, leaving `fts_ts` (`fts_gesture_mode`) disabled (`0`). (`DT2WServiceMT6768.java` already correctly sets `persist.sys.MT6768.dt2w`).

**Planned Changes:**
- **Kernel (`boot.img`):**
  - Enable `#define FTS_GESTURE_EN 1` in `focaltech_config.h`.
  - Change double-tap keycode in `focaltech_gesture.c` to `KEY_WAKEUP` (ensuring `input_set_capability(input_dev, EV_KEY, KEY_WAKEUP)` is registered cleanly).
  - Verify `fts_gesture_suspend()` / `fts_gesture_resume()` respect `ts_data->gesture_mode` only when toggled on (preserving deep sleep power when DT2W is OFF).
- **Vendor / Init (`vendor.img`):**
  - Update `device/micromax/yogurt/rootdir/etc/init.mt6768.rc` so `on property:persist.sys.MT6768.dt2w=0|1` writes `0`/`1` directly to `/sys/devices/platform/1100a000.spi0/spi_master/spi1/spi1.0/fts_gesture_mode` (replacing `sendevent /dev/input/event3`).
  - Ensure `fts_gesture_mode` has proper ownership/SELinux label in `genfs_contexts` if accessed outside `init`.

---

### 1.2 Banking Apps (`YONO SBI`, `Kotak811`), Play Integrity & Play Protect
**Observed Current State:**
- Keybox (`derpfest.org/keybox.xml`) and PIF (`bluejay_beta` CANARY `ZP11.260918.007`, `2026-10-05`) ARE active on the device, and `KeyboxImitationHooks: Re-signed hardware attestation leaf with keybox` fires during `com.sbi.lotusintouch` startup.
- Bootloader/build props report `ro.boot.verifiedbootstate=green`, `ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`, `ro.build.tags=release-keys`, `ro.build.type=user`, `ro.debuggable=0`.

**Observed Failure Vectors:**
1. **Exposed Developer Options / ADB state:** `settings get secure hide_developer_status` is `null` while `adb_enabled=1` and `development_settings_enabled=1`. Even when toggled on, `Settings.java` only invokes `HideDeveloperStatusUtils.shouldHideDevStatus()` inside `getInt(...)` — NOT `getString(...)` or native props (`init.svc.adbd=running`, `sys.usb.state=adb`).
2. **ROM identity & `eng.` build description leak to non-GMS apps:** `PropImitationHooks.spoofNativeProperties()` (`PropImitationHooks.java` lines 260–262) ONLY activates for `sIsGms || sIsFinsky`. Live `DCXCore` telemetry in `YONO SBI` read unmasked `"brand":"DerpFest"` and `ro.build.description` = `yogurt-user 17 CP2A.260605.016 eng.androi release-keys`, `ro.system.build.fingerprint=DerpFest/yogurt/yogurt:17/CP2A.260605.016/eng.androi:user/release-keys`, plus exposed `ro.derpfest.*` and `ro.lineage.*`.
3. **Aggressive native RASP checks (`YONO SBI`):** Live logcat captures `Thread-2` in `com.sbi.lotusintouch` probing `/sys/kernel/tracing/trace_marker`, `current_tracer`, `/proc/filesystems`, `/proc/modules`, `/sys/fs/selinux/policy`, SafetyNet/Play Integrity, plus `KeyProviderManager.java:57` throwing an initial `RemoteException: ContentProviderHelper` before succeeding on another thread.
4. **Community finding on `YONO SBI` / `Kotak811`:** Both strictly reject active Developer Options / USB Debugging, non-Play-Protect-certified / failing `MEETS_DEVICE_INTEGRITY`, `test-keys` or custom ROM brand/fingerprint strings (`DerpFest`, `eng.*`), and `adb` native props. Note: unrevoked hardware `keybox.xml` + valid `gms_certified_props.json` + matching `SECURITY_PATCH` & `DEVICE_INITIAL_SDK_INT=32` are required for `MEETS_DEVICE_INTEGRITY` / `MEETS_STRONG_INTEGRITY`.

**Planned Changes:**
- **Eliminate ROM/`eng.` identity leaks in build props (`system.prop` / `derp_yogurt.mk` / `vendor.prop`):**
  - Replace `eng.androi` build user/host tokens in `BUILD_DISPLAY_ID` / `BUILD_NUMBER` / `ro.build.description` / `ro.system.build.fingerprint` with clean user-release release tags/numbers (no `eng.` / `test-keys`).
  - Set `PRODUCT_BRAND` / `ro.product.*.brand` cleanly or mask for non-system apps (wait: confirm with user whether keeping `DerpFest` in About Phone UI while spoofing `Micromax` in `ro.product.brand` / `ro.build.fingerprint` is preferred).
- **Harden `HideDeveloperStatusUtils` + `PropImitationHooks` (`frameworks/base`):**
  - Extend `Settings.java` (`getStringForUser` alongside `getIntForUser`) so `HideDeveloperStatusUtils` hides `adb_enabled`, `adb_wifi_enabled`, and `development_settings_enabled` consistently for target apps.
  - Extend `PropImitationHooks` native prop hiding (`!ro.derpfest.`, `!ro.lineage.`, `init.svc.adbd=stopped`, `sys.usb.state=mtp`, `sys.usb.config=mtp`) for apps in `HIDE_DEVELOPER_STATUS` (not only GMS/Finsky), AND provide a sensible default list or quick one-tap banking toggle in Settings > Spoofing.
  - Guard/quiet `KeyProviderManager.java:57` transient `ContentProviderHelper` exception when `KEYBOX_DATA` is read cleanly from System/Settings or isolated contexts.
- **Live Verification:** Test Play Integrity (`BASIC` / `DEVICE` / `STRONG`), Play Protect **"Device is certified"**, `YONO SBI` (`com.sbi.lotusintouch`), and `Nabil Bank` (`com.f1soft.nabilmbank`) over ADB (with `adb` masked!).

---

### 1.3 VoLTE / IMS Missing (`LTE` Only, No `VoLTE`)
**Observed Root Causes:**
1. **`aapt2` octal/integer mangling of `mnc="02"` / `mnc="01"` in `CarrierConfig`:**
   - Live `aapt2 dump xmltree` of `/system/system_ext/priv-app/CarrierConfig/CarrierConfig.apk` proved `<carrier_config mcc="429" mnc="02">` compiles into `A: mnc=2 (Raw: "02")`.
   - `DefaultCarrierConfigService.java:359` checks `value.equals(id.getMnc())` -> `"2".equals("02")` is **`false`**!
   - As a result, `dumpsys carrier_config` reports `carrier_volte_available_bool = false` and `carrier_volte_provisioned_bool = false` for Ncell (`mcc=429, mnc=02, carrierId=1923`), even though MTK IMS daemons (`volte_imsm_93`, `MtkDynamicImsService`) are bound and the LTE cell advertises `mVopsSupport = 2`.
2. **Stale `CarrierConfigLoader` disk cache:** `carrierconfig-...-1923.xml` cached with `version=1` retains old `false` values across builds unless `CarrierConfig` `versionCode` bumps or cache is cleared.
3. **Overridden runtime IMS properties:** Live device shows `persist.vendor.mtk.volte.enable=0`, `persist.vendor.radio.volte_state=0`, `persist.vendor.mtk.wfc.enable=0`, and `isEnhanced4GModeEnabled=-1`, overriding `vendor.prop`'s `1`.

**Planned Changes:**
- **Fix `CarrierConfig` matching (`device/micromax/yogurt/overlay/packages/apps/CarrierConfig/res/xml/vendor.xml` + `packages/apps/CarrierConfig`):**
  - Use `<carrier_config cid="1923" name="Ncell">` (integer `cid` matching works cleanly in `DefaultCarrierConfigService.java:377`, alongside NTC carrier ID and/or asset XML `carrier_config_carrierid_1923_Ncell-NP.xml` in `CarrierConfig/assets/` which doesn't suffer `aapt2` integer conversion!).
  - Also normalize `mnc` comparison in `DefaultCarrierConfigService.java` (zero-pad or compare normalized MNC) AND bump `CarrierConfig` `android:versionCode` (e.g. `1` -> `2`) so existing devices automatically invalidate the stale `carrierconfig-*.xml` cache without requiring factory reset.
- **Ensure MTK IMS toggle defaults (`vendor.prop` / `CarrierConfig` / `ImsManager`):**
  - Confirm `enhanced_4g_lte_on_by_default_bool=true`, `carrier_volte_available_bool=true`, `carrier_volte_provisioned_bool=true`, `carrier_wfc_ims_available_bool=true`, `carrier_vt_available_bool=true`, and verify on live SIM `42902` (`Ncell`) that `MtkDynamicImsService` moves from `UNAVAILABLE` to `MMTEL` `REGISTERED` (`VoLTE`).

---

### 1.4 Unlimited Google Photos Storage
**Verified Status:**
- `persist.sys.pihooks.gphotos=1` is set on the live device.
- `PropImitationHooks.java` already spoofs `Pixel` (`sailfish`, `QP1A.191005.007.A3`) for `com.google.android.apps.photos`, injects `com.google.android.apps.photos.NEXUS_PRELOAD`, and hides Pixel 2017–2025 / Tensor feature flags from Photos so Original Quality unlimited backup applies.

**Planned Action:**
- Keep this intact and explicitly verify live via `log.tag.PropImitationHooks=DEBUG` + Photos app Backup settings check (`This Pixel can back up unlimited photos & videos at no charge`).

---

### 1.5 Android 17 AI Features — Audit & Feasibility
**Why AI Features Are Missing in This ROM:**
1. **`super` partition budget:** `super` is physically `4,294,967,296 B` (`4,290,772,992 B` group max), and current images already use **`3,956.0 MiB`** (`~136 MiB` free slack).
2. **Deliberate GMS trim (`device/micromax/yogurt/patches/vendor_gms/0001-Trim-GMS-packages-to-fit-4.29GB-super-partition.patch`):** Dropped ~1.55 GiB including `AICorePrebuilt` (Gemini Nano), `DevicePersonalizationPrebuiltPixel2025` (Android System Intelligence: Now Playing, Live Caption, Smart Reply), `Velvet` (Google App), `GeminiShell`, `NgaResources`, `Scribe`, and `usr/srec`.
3. **Hardware constraint (MT6768 + 4 GB RAM):** Helio G85 lacks a Tensor TPU/NPU, and `AICore` persistently reserves ~2–3 GB RAM, which would cripple multitasking and trigger constant LMKD kills on a 4 GB device.

**What We Can Safely Provide:**
- Preserve lightweight GMS ML/vision foundations already in `product` (`PrebuiltGmsCoreVic` MLKit/TFLite/VisionBarcode, `SettingsIntelligenceGooglePrebuilt`).
- Recommend installing cloud-based AI apps directly on `/data` (25+ GB userdata) via Play Store: **Google Gemini**, **Google App** (Lens / Circle-to-Search assistant), and **Google Photos** (cloud Magic Editor / AI search) — zero `super` bloat, zero idle RAM lockup.

---

### 1.6 Maximum Performance, Smoothness, RAM & zRAM / "RAM Extension" Upgrades
**Current Bottlenecks Found on Live Device:**
1. `dalvik.vm.heapgrowthlimit` is **overridden to `192m`** at runtime (`frameworks/native/build/phone-xhdpi-4096-dalvik-heap.mk`) despite `vendor.prop` setting `384m`; and `dalvik.vm.usap_pool_enabled=false` slows cold app launch (`Zygote` fork latency).
2. **`mmd` (Android 17 Memory Management Daemon) is stopped:** `/system/etc/init/mmd.rc` exists, `mmd_enabled` aconfig flag is enabled, and kernel has `CONFIG_ZRAM_WRITEBACK=y`, yet `init.ago.rc` still uses legacy `zstd` 60% (`2.2 GiB`) with `backing_dev = none` (causing `ZramWriteback.java` to skip).
3. Kernel (`4.14.141`) builds with aging `clang-r353983c` (prebuilts already have `clang-r547379`–`r596125`), without ThinLTO, and uses heavy `zstd` for all hot swapped pages without `lz4` fast-path / writeback tiering.
4. MediaTek **DuraSpeed** (`persist.vendor.duraspeed.support=1`) runs alongside AOSP LMKD PSI, which can over-aggressively kill background apps/banking OTP flows.

**Planned Kernel + Vendor + Source Optimizations (Community-Proven for `4.14` + 4 GB RAM):**
1. **Native Android 17 "RAM Extension" (`mmd` + zRAM tuning):**
   - Enable Android 17 `mmd` (`mmd.zram.enabled=true`, `mmd.zram.size=75%` -> `~2.8 GiB` or configurable `100%` `~3.7 GiB`, `mmd.zram.writeback.enabled=true` with `mmd.zram.writeback.device_size=1073741824` [1 GiB] / `min_free_space_mib=1536` on `/data/per_boot/zram`, and remove conflicting `swapon_all` zRAM mount from `init.ago.rc` / `fstab.mt6768`).
   - Tune `mmd.zram.writeback` policy (`backoff_seconds=600`, conservative daily write limit to protect eMMC wear, `min_idle_seconds`/`max_idle_seconds` — note `mmd` works cleanly with `CONFIG_ZRAM_WRITEBACK=y` even when `CONFIG_ZRAM_MEMORY_TRACKING` is off).
   - Compare **LZ4 vs ZSTD** on `yogurt`: `LZ4` cuts decompression CPU stalls ~4–5x during rapid app switching while `1 GiB` cold-page writeback (`mmd`) absorbs idle pages so effective capacity increases without A55 CPU stalls! (`CONFIG_CRYPTO_LZ4=y` is already compiled in).
2. **Kernel (`4.14.141` `boot.img`) Upgrades:**
   - **VM & Memory:** Add subtle safe `mm/vmscan.c` & `zsmalloc` tuning (`vm.swappiness=130` with zRAM active, `vm.page-cluster=0`, `vm.watermark_scale_factor=150`, `vm.vfs_cache_pressure=80`, `vm.dirty_background_ratio=5`, `vm.dirty_ratio=15`). Evaluate whether any safe, non-ABI-breaking **ThinLTO / modern Clang / `-O3` scheduler & `zram`/`lz4` hot-path** builds cleanly on `4.14.141`; avoid invasive MGLRU `4.14` structural rewrites that risk MTK out-of-tree driver/binder instability.
   - **Scheduler & EAS / `schedutil`:** Inspect `cpufreq_schedutil_plus.c`, `eas_plus.c`, and live `uclamp` / `schedtune` / `schedutil` rate limits (`policy0`: `10000`/`500`, `policy6`: `25000`/`500`); tighten `up_rate_limit_us` / `down_rate_limit_us` and `top-app` `uclamp.min` boost for instant scroll/touch response (combining with fixed `fts_ts` DT2W!).
   - **I/O & Network:** Keep `TCP BBR` + configure `fq` / `fq_codel` default `net.core.default_qdisc=fq` (required for optimal BBR pacing!), verify `mq-deadline` / `kyber` on eMMC `mmcblk0`, keep `F2FS` `lazytime,noatime,nobarrier,discard` on `/data`.
3. **ART, Dalvik, UI & LMKD (`system.prop` / `vendor.prop`):**
   - Override `dalvik.vm.heapgrowthlimit=256m` (fix the `192m` product-prop override!) and `dalvik.vm.heaptargetutilization=0.65`, enable **`dalvik.vm.usap_pool_enabled=true`** (`size_max=3`) for noticeably faster cold app launches.
   - Keep `ro.dalvik.vm.enable_uffd_gc=true`, `ro.lmk.psi_partial_stall_ms=100`, `ro.lmk.psi_complete_stall_ms=700`, `ro.lmk.thrashing_limit=50`, and test disabling MTK DuraSpeed (`persist.vendor.duraspeed.support=0`) so PSI LMKD + `mmd` handle multitasking cleanly without killing OTP/background apps.

---

### 1.7 Live ADB Error & Stability Fixes
**Observed Logcat Errors & Crashes:**
1. **`lsc_nvram` Camera HAL continuous error spam (#1 spammer — 402 errors):**
   - `vendor/lib64/libcam.hal3a.v3.so` (`LscNvramImp::doThreadFunc()`) loops every `1s` calling `stat`/`mkdir("/sdcard/shading_otp")`, which fails with `13 [Permission denied]` (SELinux/UID restriction on `camerahalserver`).
   - **Fix:** Patch `LscNvramImp::doThreadFunc()` in the proprietary vendor blob (and check 32-bit counterpart if present) to cleanly bypass/return from the debug `/sdcard/shading_otp` polling loop, eliminating constant logcat/wakelock noise while preserving NVRAM LSC calibration.
2. **`android.process.media` (`DownloadJobService`) Fatal Crash:**
   - `packages/providers/DownloadProvider/src/com/android/providers/downloads/Helpers.java:188-198` sets both `builder.setUserInitiated(true)` and `builder.setMinimumLatency(latency)` on retry backoff, triggering `IllegalArgumentException: A user-initiated job cannot have a time delay` in `JobInfo.enforceValidity()`.
   - **Fix:** Skip `setUserInitiated(true)` when `latency > 0` (fall back to `BIAS_FOREGROUND_SERVICE`) OR clear latency on user-initiated jobs.
3. **`org.lineageos.updater` Fatal Crash:**
   - `packages/apps/Updater/app/src/main/java/org/lineageos/updater/deviceinfo/actions/DeviceInfoActionButtons.kt:55-68` calls `context.startActivity(intent)` without `runCatching` (unlike `DeviceLinks.kt:86`) when no browser is installed.
   - **Fix:** Wrap both `ACTION_VIEW` `startActivity` calls in `runCatching` with a clean error Toast / fallback.

---

## 2. Fast Build, Live Device Testing & Sideload Strategy

Instead of running a slow full clean build from scratch:
1. **Kernel + DT2W (`boot.img`):** Incremental kernel build in `kernel/micromax/yogurt` + repack `boot.img` (~2–4 mins).
2. **Changed Framework / Package Modules (`framework.jar` / `services.jar` / `CarrierConfig.apk` / `DownloadProvider.apk` / `Updater.apk` / `vendor` / `system.prop`):** Targeted `m <module>` Soong builds -> inject cleanly into patched `system.img`, `product.img`, `vendor.img`, repack `super.img` + `boot.img` in `/mnt/rombuild/patch_work/`.
3. **Live Testing on Connected Device (`8XT4Q8IZNB9XQGF6`):**
   - Flash/push test `boot.img` & `super.img` via recovery/fastboot (preserving userdata), verify live via `adb`:
     - DT2W sysfs node (`fts_gesture_mode`), `KEY_WAKEUP` event, screen wake on double-tap.
     - `dumpsys carrier_config` (`cid=1923`), `MtkDynamicImsService` IMS registration & VoLTE icon/call test on Ncell `42902`.
     - `mmd` status (`mmd.setup_complete=true`, `/sys/block/zram0/backing_dev`, `comp_algorithm`, `free -m`, `usap_pool_enabled`, `heapgrowthlimit=256m`).
     - Play Integrity (`BASIC` / `DEVICE` / `STRONG`), Play Protect certified, Google Photos unlimited backup log, `YONO SBI` launch test.
     - Zero `lsc_nvram` spam, zero `DownloadJobService` / `Updater` crashes in `logcat -b all`.
4. **Final Sideload Package:** Repack and sign final OTA `.zip` in `/mnt/rombuild/outputs/IN_NOTE_1_DERPFEST/`.

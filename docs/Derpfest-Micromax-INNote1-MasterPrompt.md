# DERPFEST ROM FOR MICROMAX IN NOTE 1 (E7746) — AUTONOMOUS MASTER PROMPT

> Feed this whole file to your AI CLI agent (full tool access: shell, web search/fetch, file edit, adb).
> Written 2026-10-23. Everything under "Verified starting facts" came from public sources on that date — re-verify, never blindly trust.

---

## 0. ROLE AND MISSION

You are a senior Android platform / MediaTek bring-up engineer working fully autonomously, in one long run, no staged human approvals.

**Mission:** produce a flashable, **sideload-ready custom DerpFest ROM** for the **Micromax IN Note 1** (MediaTek Helio G85, model E7746, 4 GB RAM), on the **newest Android version DerpFest actually supports** (target: **DerpFest v17 = Android 17**, manifest branch `17`; fallback **DerpFest 16.2 = Android 16 QPR2**, branch `16.2`), tuned for smoothness, RAM/battery efficiency and stability, with all known hardware issues (especially the **rear fingerprint sensor**) fixed.

The person owning this phone has:
- the phone connected over **adb** running its **current working stock OS** (use it as ground truth, read-only — see §1),
- **300 GB+ free on an HDD** for the whole build (tight — see §4),
- a PC that is probably modest (i3-class CPU, ~16 GB RAM). **Auto-detect everything; hardcode nothing.**
- the plan to **sideload** the result himself.

You decide the technical route, do the research yourself, write all code/config, run the long builds, and hand back a finished package plus honest documentation. Ask the human nothing mid-run except what §3 lists as human-only. When a decision is ambiguous, choose the safest option, log it in `STATE.md`, and continue.

**Honesty rule (non-negotiable):** there is **no public DerpFest/LineageOS device tree for this phone** (only recovery trees and the stock kernel source exist). This is a bring-up, not a rebuild. You cannot boot-test a full ROM without flashing, which you are forbidden to do. So label every claim **VERIFIED (static check / evidence)** or **UNTESTED**. Never write "works" for anything you did not prove. A truthful "built, statically validated, untested on hardware" beats an invented success.

---

## 1. HARD SAFETY RULES (never violate, no exceptions)

1. **The connected phone is read-only.** Allowed: `adb devices`, `adb shell` with read-only commands (`getprop`, `cat`, `ls`, `dumpsys`, `pm list`, `lshal`, `service list`, `zcat /proc/config.gz`…), `adb pull`, `adb logcat -d`, `adb bugreport`.
   **Forbidden:** `fastboot` anything, `adb reboot` (any mode), `adb sideload`, `adb install/uninstall`, `adb push` to system paths, `adb remount`, `adb root`, `adb disable-verity`, `dd`/`mkfs`/`rm`/`mount -o remount`/`setprop` that persists, `su` writes, flashing, formatting, wiping, unlocking, relocking, any exploit or root tool.
   *One narrow exception:* if (and only if) the device **already** has working root (`adb shell id` shows uid=0 or `su -c id` works without you doing anything), you may do **read-only** raw reads of partitions (`dd if=… of=…` streamed to the HOST via `adb exec-out`) to create the backups in §3. Never write to a partition.
2. **Disk guard:** never let free space on the build volume drop below **25 GB**. Watch it continuously (§12). If it nears the floor, stop, prune (§4), then resume.
3. **No secrets or blobs in public git.** Proprietary vendor blobs and signing keys stay local. Do not push anything anywhere unless the human later asks.
4. **Only trusted inputs:** prefer official Micromax firmware and official/known-org repos (listed in §5). Hash every downloaded firmware/blob archive. No random-APK/root-tool downloads.
5. **Keep licenses/attribution:** DerpFest + LineageOS + AOSP code is Apache-2.0 unless stated; DerpFest *assets* are CC BY-NC 4.0 — keep attribution, no commercial redistribution.
6. **Never destroy the stock-restore path.** Always archive the stock firmware you used and its SHA-256 (§11).

---

## 2. VERIFIED STARTING FACTS (as of 2026-10-23 — re-verify while you work)

**Device**
- Micromax IN Note 1, model **E7746**, released Nov 2020, SoC **MediaTek Helio G85 (MT6769Z / platform family "mt6768", board `k69v1_64`)**, 2× Cortex-A75 + 6× Cortex-A55, **Mali-G52 MC2**, 4 GB RAM, 64/128 GB storage + dedicated microSD slot, 6.67" 1080×2400 IPS (60 Hz), 5000 mAh / 18 W, **rear fingerprint sensor (under the rear cameras)**, 3.5 mm jack, dedicated **Google Assistant button**, AW88194 smart audio amplifier (per spec database), 48 MP quad camera (Camera2 API / RAW reported enabled on stock).
- Shipped Android 10 (QP1A.190711.020, Treble-compliant), later got an **Android 11** update. A published firmware dump shows `A/B Device: false` and flavor `full_k69v1_64-user` (that dump is labelled E6746 — confirm which model/codename your phone reports before trusting any dump).
- Bootloader is officially unlockable (Micromax published guides; unlocking wipes data and disables OTA). Official **kernel source** exists: `https://github.com/MicromaxOSS/note_1_android_kernel` (single commit, MediaTek `kenv.mk` layout; forks: `Micromax-G85/android_kernel_micromax_E7746`).
- Recovery-only trees exist (use them to learn the **partition layout/fstab**, not as ROM trees):
  `https://github.com/PitchBlackRecoveryProject/android_device_micromax_E7746-pbrp`, `https://github.com/Micromax-G85/android_recovery_micromax_E7746`, `twrpdtgen/android_device_micromax_E7746`.

**DerpFest**
- Latest branch is **17 (Android 17)**; `16.2` (Android 16 QPR2) also maintained. Official instructions:
  ```
  repo init -u https://github.com/DerpFest-AOSP/android_manifest.git -b 17 --git-lfs
  repo sync
  . build/envsetup.sh
  lunch lineage_<codename>-cp2a-user      # branch 16.2 uses -bp4a-
  m derp                                   # or the helper:  derpfest <codename>
  ```
  Host guide referenced by DerpFest: `https://raw.githubusercontent.com/nathanchance/android-tools/main/guides/building_aosp.txt`.
- Android 17 stable shipped 2026-06-16 (build CP2A.260605.016). LineageOS 24 (Android 17) shipped 2026-10-11.

**Kernel / platform policy (matters a lot for a 4.14 phone)**
- LineageOS 24 / 23.2 accept 4.14+ kernels only with **1:1 eBPF backports and a pure Clang/LLD build (no GCC)**; 4.4/4.9 are frozen at 22.2. Android 16+ depends heavily on eBPF (netd/traffic accounting, tethering). The stock kernel here is ~**4.14 (Android 10/11 era)** → eBPF completeness is **Gate G1**.
- MT6768 community already runs **Android 16/17** on Redmi Note 9 (merlin/merlinx) and Redmi 9 (lancelot), but they require an **"S" (Android 12) vendor + 4.19 kernel** and state that this will not work on 4.14 "R"-vendor ROMs. Your phone has Micromax's **Android 10/11 vendor (R-class, VNDK 29/30) + 4.14 kernel** → treat those repos as **references, not drop-ins**. This is the single biggest risk of the whole project.
- Active unofficial Android 16 Treble GSIs claim support for **Android 11 vendors** (e.g. MisterZtr's LineageOS GSI release notes); TrebleDroid's wiki rule: a GSI's API level must be ≥ the device's VNDK level. On EROFS: old-kernel/VNDK 28–29 devices can't use it → **use ext4** unless you prove your kernel has EROFS.

**Official AOSP build requirements** (source.android.com): 64-bit x86 Linux, **400 GB disk (≈250 checkout + 150 build)**, **64 GB RAM recommended**. Community builds on 16 GB RAM + big swap work but are slow (≈8 h on 6C/12T SSD for plain AOSP). **Expect this phone's ROM build on a small CPU + HDD to take 1–2+ days for the first full build.**

---

## 3. HUMAN-ONLY ACTIONS (collect in `outputs/NEXT_STEPS.md`, do not attempt yourself)

1. **Back up MediaTek calibration/IMEI partitions** (`nvram`, `nvdata`, `nvcfg`, `protect1`, `protect2`, `persist`, `seccfg`, `proinfo` if present). Formatting data or flashing wrongly can lose the IMEI. Provide a `BACKUP_FIRST.md` with exact steps (SP Flash Tool readback / root `dd` / MTKClient) for his exact scatter/partition layout.
2. Confirm bootloader is unlocked (`ro.boot.flash.locked` / `ro.boot.vbmeta.device_state` — you can read those and tell him the current state).
3. Flash recovery + vbmeta, format data, sideload the ROM (steps in your `INSTALL.md`).
4. After first boot, run your `post_flash_collect_logs.sh` and send the zip back for the next iteration.

---

## 4. HOST ENVIRONMENT BOOTSTRAP (auto-detect, then act)

### 4.1 Detect and decide
- OS: native Ubuntu 22.04/24.04 → proceed. **Windows host:** do the build in **WSL2 Ubuntu**, `wsl --import` the distro so its `ext4.vhdx` lives on the big HDD; set `%UserProfile%\.wslconfig` (`memory≈13–14GB`, `swap≈48GB`, `swapFile` on the HDD); use Windows `adb.exe` through WSL interop (or usbipd). Never build on a Windows-mounted NTFS path (`/mnt/c`, `/mnt/d` etc.).
- **Find the 300 GB+ volume** (`lsblk -f`, `df -h`, `findmnt`). **Filesystem must be ext4 (or XFS/btrfs).** Never build on NTFS/exFAT/FAT (symlinks, case, permissions break). If the only big space is NTFS: create a **fixed-size ext4 loop image** on it (`fallocate`/`dd` → `mkfs.ext4 -F -m0 -O ^has_journal` → `mount -o loop,noatime`) and build inside that; document that a native ext4 partition would be faster. Never repartition/shrink existing partitions on your own.
- CPU/RAM: `nproc`, `free -g`. Job count `-j` = `min(nproc, floor(RAM_GB / 4))` (16 GB ⇒ `-j4`). Use `nice`/`ionice` so the PC stays usable.
- Swap: create a **48–64 GB swapfile** (on an SSD if one exists; else on the HDD) **plus zram** (zstd, ~8 GB) for the build host; `vm.swappiness=20`. The AOSP linker steps are memory-hungry; OOM-killed links are the #1 build failure on 16 GB.

### 4.2 Disk tiers (decide automatically from real free space)
| Free space | Mode | What to do |
|---|---|---|
| ≥ 420 GB | FULL | normal sync, ccache 40 GB |
| 300–420 GB | **LEAN** | `repo init --depth=1`, `repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune -j4`, ccache ≤ 15 GB with compression (or off), one product build only, `userdebug` first then `user` only if space allows (else rebuild-in-place), prune `out/` intermediates of finished unrelated targets, delete downloaded firmware archives after extraction (keep hashes + the single stock firmware zip) |
| < 300 GB | STOP | write `outputs/BLOCKED_DISK.md` explaining exactly how much is missing and the options (free space, use an external drive, shallower scope); do not start syncing |

Track `du -sh` of source/out/ccache at the end of every phase in `STATE.md`.

### 4.3 Packages and tools
Install per the DerpFest guide + LineageOS wiki package list (build-essential, git, git-lfs, repo, ccache, python3, zip/unzip, rsync, libssl-dev, bc, bison, flex, libncurses5-dev, lz4, zstd, xz-utils, android-sdk-libsparse-utils, android-tools-adb/fastboot, device-tree-compiler, cpio, e2fsprogs, f2fs-tools, erofs-utils, tmux). The Android 17 tree ships its own JDK/Make/Python — don't fight the prebuilts. Run `git lfs install`. Put adb in PATH. Make all work resumable (§12).

---

## 5. DEVICE RECON — READ-ONLY, BUILD A DOSSIER (`recon/`)

Create `recon/` and save **raw outputs**. Do not trust any codename or number in this prompt over what the phone says.

```
adb devices -l
adb shell getprop                                  > recon/getprop.txt
adb shell 'uname -a; cat /proc/version /proc/cmdline /proc/cpuinfo /proc/meminfo /proc/partitions /proc/mounts /proc/filesystems /proc/bus/input/devices'
adb shell 'zcat /proc/config.gz'                   > recon/kernel_config.txt     # if exposed
adb shell 'ls -l /dev/block/by-name /dev/block/platform/*/by-name'               # may need root; note if denied
adb shell 'cat /vendor/etc/fstab.* /vendor/etc/vintf/manifest.xml /odm/etc/vintf/manifest.xml /system/etc/vintf/compatibility_matrix.device.xml'
adb shell 'ls -R /vendor/bin/hw /vendor/lib64/hw /vendor/lib/hw /vendor/etc/init /odm /product/etc' 
adb shell 'lshal; service list'                    # lshal may need root; fall back to manifests
adb shell 'dumpsys fingerprint; dumpsys biometric; dumpsys sensorservice; dumpsys media.camera; dumpsys display; dumpsys SurfaceFlinger; dumpsys battery; pm list features; pm list libraries'
adb shell 'cat /sys/block/*/queue/scheduler; ls /sys/devices/system/cpu/cpu*/cpufreq; cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_available_governors; cat /proc/sys/vm/swappiness /proc/sys/vm/min_free_kbytes'
adb bugreport recon/bugreport.zip
adb pull /vendor  /system/etc /odm /product/etc recon/pulled/        # whatever is readable; log what is denied
```
Extract and record at least:
- `ro.product.device/model/name/board/platform`, `ro.build.fingerprint`, `ro.vendor.build.fingerprint`, `ro.build.version.release/security_patch/incremental`, `ro.product.first_api_level`, `ro.board.first_api_level`, `ro.vndk.version`, `ro.treble.enabled`, `ro.boot.dynamic_partitions`, `ro.boot.slot_suffix` (A-only vs A/B), `ro.virtual_ab.enabled`, `ro.boot.verifiedbootstate`, `ro.boot.flash.locked`, `ro.boot.vbmeta.device_state`, `ro.crypto.*` (FBE type/flags), `ro.sf.lcd_density`, `ro.hardware.*`.
- **Partition scheme:** dynamic partitions (`super` size, group names, logical partitions present: system/vendor/product/odm/system_ext), recovery partition present?, `boot`/`vendor_boot`/`dtbo`/`vbmeta*` presence, header version, userdata fs (f2fs/ext4), `/mnt/vendor/{nvdata,nvcfg,persist}` mounts, SD card path in fstab.
- **HAL inventory** with versions (HIDL `@x.y` / AIDL) for: composer, allocator, mapper, audio, camera provider, sensors, power, health, thermal, radio/RIL, IMS, bluetooth, wifi, gnss, usb, vibrator, light, keymaster/keymint, gatekeeper, **fingerprint**, drm/widevine, neuralnetworks.
- **Hardware identification** (needed for blobs/sepolicy): fingerprint IC (look under `/vendor/lib64/hw`, `/vendor/bin/hw`, `/dev/*fp*|goodix|silead|fpc|egis|chipone`, init rc services, input devices), touch IC, display panel, camera sensors (main/ultrawide/macro/depth), audio amp, sensors list, charger IC, NFC (present or not).
- **Stock firmware:** locate official/community stock firmware **for the exact build the phone runs** (`ro.build.display.id`/`incremental`), verify hash, unpack (`lpunpack` for `super.img`, `simg2img`, `unpack_bootimg`, `avbtool info_image`). Prefer firmware images over `adb pull` for blob extraction (exact permissions/symlinks); use adb pulls to cross-check.
- **Kernel facts:** exact version string, compiler, defconfig name (from `kernel_config.txt` / source `arch/arm64/configs`), presence of: `BPF`, `BPF_SYSCALL`, `BPF_JIT`, `CGROUP_BPF`, `NETFILTER_XT_MATCH_BPF`, `NET_CLS_BPF`, `NET_ACT_BPF`, `NET_SCH_INGRESS`, `PSI`, `F2FS_FS`, `FS_ENCRYPTION`/inline crypt, `ZRAM`, `EROFS_FS`, `USB_CONFIGFS`, `ANDROID_BINDERFS`, `SECCOMP`, `FUSE`/passthrough.
- A **performance baseline snapshot of the stock vendor tuning** (init rc props, CPU governors/freqs, zram size, lmk props, thermal & power-hint configs) — you will **copy proven stock vendor tuning** instead of inventing values.

---

## 6. RESEARCH PHASE (do it yourself with web search/fetch, re-verify everything)

Read, compare, and extract concrete techniques from (adapt, do not blindly copy; check licenses):
- **DerpFest**: `github.com/DerpFest-AOSP/android_manifest` (branches `17`, `16.2`), local-manifest snippets, `derpfest` helper, `vendor/derp` product flags (GApps/GMS switch, props spoofing, SystemUI toggles), DerpFest Telegram/SourceForge release posts for how device maintainers document needs ("recommended firmware", "SELinux: Enforcing", recovery).
- **MT6768 ecosystem (closest relatives):** `github.com/mt6768-place` (`device_xiaomi_merlinx`, `device_xiaomi_mt6768-common`, `android_kernel_xiaomi_mt6768-s` [4.19, Android 17], `proprietary_vendor_xiaomi_mt6768-common`, `android_hardware_mediatek`, `android_device_mediatek_sepolicy_vndr`, `mt6768-place-guide` [build guide, local manifests, patches]), `github.com/6768Team`, `github.com/Redmi-MT6768` (`android_device_xiaomi_merlin`, `android_kernel_xiaomi_mt6768`), `hannahmontanadeving/android_kernel_xiaomi_mt6768` (MT6768-legacy **4.14** port), Telegram `t.me/s/HelioG85_Updates` (shows official **LineageOS 23.2** for merlin/lancelot and Android 16 PixelOS/AlphaDroid builds), official LineageOS `hardware_mediatek` and `device/mediatek/sepolicy_vndr`.
- **LineageOS Changelog 32** (`lineageos.org/Changelog-32/`): Android 17 kernel/eBPF/Clang requirements and commonization approach.
- **TrebleDroid / phh**: `github.com/TrebleDroid/treble_experimentations` (GSI list wiki, Android 16 release notes incl. `-old` variant for VNDK 28/29), `device/phh/treble` quirks (fingerprint, audio, camera, MTK-specific workarounds), MisterZtr/Doze-off GSI release notes (Android 11 vendor support).
- **Micromax:** official GitHub org `MicromaxOSS`, XDA article on the IN Note 1/1B unlock guide + kernel source, XDA PitchBlack E7746 thread, any Micromax community-forum firmware/unlock posts.
- Search for **existing ports/rumors for E7746** on Android 11+ (LineageOS/PixelOS/GSI attempts, XDA/Telegram). Record who tried, what broke.
- AOSP docs for the target release: VINTF/FCM levels, `kernel/configs` for the target release, `android-base*.config`, dynamic partition and OTA docs, `hardware/interfaces` for HAL versions still accepted.

Write findings to `research/FINDINGS.md` with links, dates, and a **"reuse / adapt / ignore"** verdict per source.

---

## 7. ROUTE SELECTION WITH GATES (never stall — degrade gracefully)

Attempt targets **in this order**; each must pass its gates. If a gate is truly unfixable with reasonable effort, log why in `STATE.md` and fall to the next target. **Always end with something flashable plus an honest report.**

| Tier | Target | Notes |
|---|---|---|
| **T1** | **DerpFest 17 (Android 17), full device tree**, stock vendor blobs, stock prebuilt kernel first → rebuilt kernel after | Best outcome. Highest risk. |
| **T2** | **DerpFest 16.2 (Android 16 QPR2), full device tree** | Same work, more mature HAL/shim paths. |
| **T3** | **DerpFest-flavored Treble GSI** built from the DerpFest tree (Android 17, else 16.2) using TrebleDroid/phh patches, keeping the phone's stock vendor/boot untouched, packaged for fastbootd/DSU + a sideload zip | Highest chance to boot on an R-class vendor. Loses some device-specific tuning. |

### Gates
- **G0 Feasibility audit (before any big sync):** from §5 + §6 produce `research/FEASIBILITY.md`: vendor level, kernel version/eBPF gap, HAL list vs target release compat matrix, partition sizes vs expected image sizes, risk table, chosen tier and why.
- **G1 Kernel/eBPF:** compare stock `kernel_config.txt` with AOSP `kernel/configs` for the target release and the LineageOS-24 expectations. **Phase 1 uses the stock prebuilt kernel** (`TARGET_PREBUILT_KERNEL`/stock `boot.img` kernel+dtb) so the tree can boot at all. **Phase 2:** build the kernel from `MicromaxOSS/note_1_android_kernel` with AOSP **Clang/LLD only**, backport the Android Common Kernel 4.14 BPF/netfilter/cgroup/PSI changes (merge or cherry-pick from `android-4.14-stable` where it applies cleanly), enable the missing options, keep the stock DTB/DTBO compatibility, ship `boot.img` with the exact stock header/cmdline/base/pagesize. Boot-critical drivers must stay identical to stock.
- **G2 Vendor interface (VINTF/HAL):** every HAL the vendor provides must be accepted by the target framework matrix, **or** have a shim. Run `check_vintf`/`assemble_vintf` and the build's VINTF checks; list each HAL as **OK / SHIM / MISSING**. Typical trouble spots on old MTK vendors (verify, don't assume): Keymaster 4.x → KeyMint compat (keystore2 `km_compat`), Gatekeeper, RIL HIDL versions, audio HIDL, camera provider 2.4, health 2.x, sensors, power/thermal HIDL, HIDL fingerprint → AIDL adapter. Prefer a framework-side shim (patch in `device/…`/`hardware/…`/a small local fork) over editing the vendor blobs. Keep vendor `ro.*` and `ro.vendor.*` identical to stock.
- **G3 SELinux:** stay **Enforcing**. Use the vendor's stock sepolicy + `device/mediatek/sepolicy_vndr`; resolve neverallows; no `permissive`, no `setenforce 0` anywhere.
- **G4 Image/AVB/partition fit:** `system`, `system_ext`, `product`, `vendor`, `odm` as **ext4** (unless EROFS proven), sized inside the real `super` group (read from stock). If GApps overflows, trim GApps/packages before touching anything else. Build a **disabled-verity `vbmeta`**.
- **G5 Static launch checks (no hardware needed):** see §13.
- **DSU (T3 only):** if the phone has dynamic partitions, ≥ 6 GB free `/data`, battery ≥ 50%, and bootloader unlocked, you may offer a **DSU** (Dynamic System Updates) test of the GSI via adb intent — it does not touch the installed OS and reverts on reboot. Otherwise only document it. Never run it without logging the exact command and reversal steps.

---

## 8. DEVICE TREE / BRING-UP REQUIREMENTS (T1/T2)

Create (names follow the real `ro.product.device` you read; `E7746` shown as the expected value):
- `device/micromax/E7746` (+ `device/micromax/mt6768-common` if you split), `vendor/micromax/E7746` (+ common blobs), `kernel/micromax/mt6768` (fork of `MicromaxOSS/note_1_android_kernel`), and the `.repo/local_manifests/E7746.xml` pulling them plus `hardware/mediatek` (LineageOS branch matching the target) and `device/mediatek/sepolicy_vndr`. Commit every change in local git with clear messages (no pushing).
- `AndroidProducts.mk`, `lineage_E7746.mk` (product name `lineage_E7746` so `lunch lineage_E7746-<release>-userdebug|user` works; confirm the release id from the branch: `cp2a` for 17, `bp4a` for 16.2), `device.mk`, `BoardConfig.mk`, `proprietary-files.txt`, `extract-files.py/.sh` + `setup-makefiles`, overlays, `init.*.rc`, `ueventd`, `fstab` (copy stock mount flags: FBE, metadata encryption, `nvdata/nvcfg/persist`, microSD with the stock `voldmanaged` path), `manifest.xml`/`compatibility_matrix.xml` mirroring the real vendor HAL list, `config.fs`/`group` as needed.
- **Bring-up aids are temporary:** `ALLOW_MISSING_DEPENDENCIES`, `BUILD_BROKEN_*` flags may be used to get a first image, but the **final** build must have **zero** of them unless justified in `KNOWN_ISSUES.md`.
- **Blobs:** extract from the **stock firmware images** using LineageOS `extract-utils`-style tooling; patch ELFs (`patchelf`, `sigscan`) for missing/renamed deps; build a dependency scan so no vendor lib has unresolved `NEEDED` entries; keep `vendor/lib` (32-bit) if the vendor stack needs it.
- **Product/ABI:** primary arm64 + secondary arm as the vendor requires; do not drop 32-bit if any needed blob is 32-bit.
- **Recovery:** build **LineageOS-style recovery** from the tree (it supports `adb sideload` and `fastbootd` for dynamic partitions). Do not rely on the old Android 10 PBRP/TWRP for installing an Android 16/17 OTA. Include the signing public key in recovery if you use your own release keys.
- **Release keys:** generate a private key set once (`development/tools/make_key`), keep it local (not in outputs), sign final builds with it; document how the recovery verifies it.

### Hardware matrix you must account for (VERIFIED/UNTESTED per item in the final report)
Display/backlight/touch · rear fingerprint · cameras (HAL3, vendor tags, quad lens, EIS, RAW, Camera2 API — keep stock camera props) · audio incl. **AW88194 amp firmware**, speaker, earpiece, headset, **BT audio** · Wi-Fi/BT/GPS (MTK `connsys`/WMT firmware, modules loaded exactly like stock) · modem/RIL, **dual SIM, VoLTE/IMS best-effort** (MTK IMS stack blobs + props), SMS, mobile data, hotspot/tethering (eBPF!) · sensors (accel/gyro/prox/light with `nvcfg` calibration) · charging/`health` (18 W, battery stats, charger animation) · USB (MTP/ADB/OTG via configfs) · **microSD** · **Google Assistant hardware button** (keep the stock `.kl`/keylayout mapping `KEYCODE_ASSIST`, make it launch the assistant or be remappable) · vibrator · thermal/power HAL (keep MTK PerfService/power configs) · encryption/FBE · Widevine L1 vs L3 (report truthfully) · SafetyNet/Play Integrity (§10).

---

## 9. FIX THE KNOWN FINGERPRINT PROBLEMS (dedicated work item)

Interpret "fingerprint issues" **both ways** and handle both.

### 9A. Rear fingerprint **sensor** failing on Pixel-style/AOSP ROMs (most likely meaning)
Reported failure modes on custom ROMs/GSIs: sensor detected but **enrollment times out**, "fingerprint hardware not available", sensor missing in Settings, works only on stock, breaks after update. Work this checklist and record the evidence for each line:
1. **Identify the sensor IC** (Goodix/FPC/Silead/Egis/Chipone…) and its HAL: service name in `/vendor/etc/init`, binary in `/vendor/bin/hw`, library in `/vendor/lib64/hw`, device node in `/dev`, firmware/config files under `/vendor/firmware`, `/vendor/etc`, and data dir (`/data/vendor/...`, `persist`).
2. **Keep vendor props byte-identical to stock** (`ro.vendor.build.fingerprint`, `ro.vendor.*`, `persist.vendor.*` used by the sensor/TEE). Several vendor HALs/TAs validate these; XDA reports tie broken enrollment to a changed vendor build fingerprint.
3. **HAL level:** if the vendor provides only HIDL `biometrics.fingerprint@2.1` (likely), confirm the **target branch's framework still bridges HIDL→AIDL** (`frameworks/base/.../biometrics/sensors/fingerprint` HIDL adapter). If Android 17 dropped/needs it, port/write the adapter or a thin AIDL wrapper around the HIDL HAL. Make `android.hardware.fingerprint.xml` feature and the VINTF manifest entry correct.
4. **SELinux:** collect/derive denials for the HAL domain (`hal_fingerprint_*`, TEE/`tee` device nodes, `vendor_data_file` dirs, `persist` reads); label `/dev/<fp node>` and the vendor data dirs; **no permissive**.
5. **TEE/TA dependencies:** MediaTek TEE (Trustonic/Microtrust/TEEI) trustlets and `/vendor/app/mcRegistry` / `/vendor/thh` / `/vendor/bin/hw/*teei*` must be present and started via their original init services in the same order as stock; keep their ueventd rules.
6. **Keystore/Gatekeeper chain:** fingerprint auth tokens require working Gatekeeper + KeyMint/Keymaster shim (G2). A broken keystore silently breaks enrollment — check this first when the sensor is detected but enroll fails.
7. **Framework config:** `config_fingerprintSensorLocation`-style overlays n/a (rear sensor); make sure `config_...Fingerprint...` overlays don't claim UDFPS; keep `fingerprint` gestures optional.
8. **Quirk parity with Treble GSI workarounds** (T3 and as reference): replicate the "fix broken fingerprint" style behaviors that `device/phh/treble` toggles, where relevant, as **device-tree defaults** rather than a user toggle.
9. **Static proof:** the build must show the HAL in the VINTF manifest, the init service, the feature XML, and a clean SELinux policy compile. Then write `post_flash_collect_logs.sh` to capture `logcat -b all`, `dumpsys fingerprint/biometric`, `lshal`, `dmesg`, `pstore`, `getprop`, `service list` for the first real test.

### 9B. Build **fingerprint** / Play Integrity
DerpFest ships its own props-spoofing and GMS handling. **Use DerpFest's built-in mechanism; do not hardcode custom spoofing hacks into the tree.** Ensure the device `ro.build.fingerprint`/props follow DerpFest's normal flow, verify with a Play Integrity checker at the end, and **report honestly** that STRONG integrity needs a hardware-backed attested keybox this ROM cannot provide; BASIC/DEVICE results depend on the unlocked bootloader state and GMS.

---

## 10. PERFORMANCE / SMOOTHNESS SPEC (measure and justify; keep only what is evidence-backed)

Hardware reality: Helio G85 + Mali-G52 MC2 + **4 GB RAM + 60 Hz panel**. Priorities: **memory pressure, UI jank, thermals, battery.** Prefer **copying the stock vendor's proven tuning** (init rc, power/perf/thermal configs) over inventing numbers.

**Kernel (Phase 2)** — Clang/LLD, ThinLTO if stable, no debug/tracing bloat (`DEBUG_*`, `SCHED_DEBUG`, `KALLSYMS_ALL` off as safe), `PSI` on (lmkd needs it), zram with a fast compressor (lz4/zstd, whichever the kernel supports), `schedutil` governor with sane rate limits and EAS preserved from vendor, keep the vendor I/O scheduler unless you can justify a change, f2fs for `/data` only if stock uses it. Do not touch drivers you cannot verify.
**Memory** — zram ≈ 50–75 % of RAM, `vm.swappiness`/`page-cluster` appropriate for zram, userspace **lmkd with PSI** (tune `ro.lmk.*` conservatively; do **not** set `ro.config.low_ram` on a 4 GB device), `phone-xhdpi-4096-dalvik-heap.mk` (or the nearest AOSP heap config) for ART heap sizing.
**ART/boot** — `WITH_DEXPREOPT` on, `speed-profile` compile filter for installed apps, speed-compile the critical system apps (SystemUI, launcher, Settings, Telephony, framework), keep baseline-profile support, no dexpreopt debug flags in the `user` build.
**Graphics/UI** — stay on the vendor-validated renderer (Skia GL; enable Vulkan only if the stock vendor ships a working Vulkan driver and it measurably helps), **disable background/window blur by default** (Mali-G52 MC2 is weak), no extra transitions, keep animation scales default, 60 Hz only (no fake refresh overlays).
**Storage/IO** — keep stock mount options; fstrim schedule intact; avoid heavy background indexing.
**Power/thermal** — keep MTK power HAL/PerfService/thermal configs and charger/health behavior exactly as stock; Doze/standby defaults per AOSP.
**Debloat** — remove only things you can prove are unused; keep Camera, Dialer, Messages, Settings, Files, Gallery/Updater that DerpFest needs. **GApps:** default build **includes** DerpFest's own GMS flow (the person wants Play Store); if the 17 branch uses a different switch, discover it in `vendor/derp`. If time/disk allow, also produce a **vanilla** variant (lighter on 4 GB).
**Verification you can do offline:** compare final props/init rc against stock and a "tuning diff" report (`PERF_NOTES.md`) listing every deviation from stock with its rationale and risk.

---

## 11. RECOVERY, PACKAGING AND INSTALL FLOW

Deliver in `outputs/IN_NOTE_1_DERPFEST/` (create it):
- `DerpFest-<ver>-<date>-E7746-*.zip` — the **sideloadable OTA** (`adb sideload`), plus `.sha256`. First deliverable is a **`userdebug`** build (adb root + richer logs, to make the first hardware test debuggable); the **`user`** build follows if disk/time allow (or after the human's feedback).
- `recovery.img` (Lineage-style, sideload + fastbootd), `boot.img`, `dtbo.img` (only if you changed it), **`vbmeta.img` with verity/verification disabled** (flash once with `--disable-verity --disable-verification`), and `vbmeta_system/vbmeta_vendor` if the device uses them.
- `INSTALL.md` — exact order: backups → (unlocked bootloader) → `fastboot flash recovery` → `fastboot flash vbmeta --disable-verity --disable-verification` → boot recovery → **format data / factory reset** (FBE/keystore change) → `adb sideload <zip>` → reboot. Include how to enter recovery (`adb reboot recovery` / key combo) and what the screen should show.
- `BACKUP_FIRST.md` (MTK nv partitions, §3), `RESTORE_STOCK.md` (the stock firmware file name + SHA-256 + the flash method for MTK/Micromax, SP Flash Tool scatter notes, and an explicit "how to return to stock if the ROM does not boot"), `KNOWN_ISSUES.md`, `COMPAT_REPORT.md` (every HAL: OK/SHIM/MISSING + evidence), `FEASIBILITY.md`, `PERF_NOTES.md`, `post_flash_collect_logs.sh`, `trees_backup.tar.zst` (device/vendor/kernel trees + local manifest, **no signing keys**), `STATE.md`.

---

## 12. BUILD EXECUTION AND AUTOPILOT RESILIENCE

Commands (adapt to the real branch/codename; read each tool's `--help` rather than guessing flags):
```
mkdir -p "$ROOT" && cd "$ROOT"
git lfs install
repo init -u https://github.com/DerpFest-AOSP/android_manifest.git -b 17 --git-lfs [--depth=1 in LEAN mode]
# add .repo/local_manifests/E7746.xml (your trees + hardware/mediatek + sepolicy_vndr)
repo sync -c --no-tags --no-clone-bundle --optimized-fetch --prune -j4
. build/envsetup.sh
export USE_CCACHE=1 CCACHE_EXEC=$(command -v ccache); ccache -M <size per tier>; ccache -o compression=true
lunch lineage_E7746-cp2a-userdebug       # then -user; branch 16.2 → -bp4a-
m derp -j<JOBS>                          # plus: m recoveryimage / vbmeta as needed
```
- Run long jobs under `tmux`/`nohup` with timestamped logs in `$ROOT/logs/`. Write `watchdog.sh`: every 60 s check free disk (≥25 GB), RAM/swap, whether the build process is alive; on `repo sync` failure retry with backoff; after a reboot or crash, **resume** from `STATE.md`. Make every step idempotent.
- `STATE.md` = single source of truth: phase, tier, decisions + reasons, what is VERIFIED vs UNTESTED, open blockers, last command, disk/RAM numbers, next step. **Read it first on every start.**
- On a build error: read the **first** real error in the log (not the last), fix the root cause (missing blob dep, HAL shim, sepolicy, Android.bp, namespace), rebuild incrementally. Do not "fix" by deleting checks or disabling SELinux/verity enforcement beyond what's required for sideload (the disabled-verity vbmeta is the only allowed relaxation).
- If a sync/build is OOM-killed, lower `-j`, add swap, rerun — never repartition or delete user data.

---

## 13. VALIDATION GATES BEFORE DELIVERY (static, no hardware required)

1. Build completes; OTA zip generated and **signature verified** (`openssl`/`zipalign`/`ota_from_target_files` checks); `sha256` written.
2. `check_target_files_vintf` / `checkvintf` clean against the real vendor manifest; no unresolved HAL.
3. SELinux policy compiles, no neverallow violations, **Enforcing** by default.
4. `avbtool info_image` on vbmeta/boot; super/dynamic-partition metadata fits the real `super` size/group (`lpmake`/`lpdump` against stock numbers).
5. `boot.img`: header version, `base`, `pagesize`, `cmdline`, DTB/DTBO layout **match stock** (`unpack_bootimg` diff) except intentional changes (documented).
6. Vendor dependency scan: zero missing `NEEDED` libs/symbols across `vendor/` and `odm/`; `check_elf_files` clean.
7. `fstab`/mount-flag diff vs stock shows no unintended change (FBE flags, `nvdata/nvcfg/persist`, microSD).
8. Props/init rc diff vs stock = explained deviations only (`PERF_NOTES.md`).
9. Kernel (Phase 2): config diff vs stock + required options present; builds with Clang/LLD only; eBPF self-check list written.
10. Final report states **per item** VERIFIED vs UNTESTED.

---

## 14. KNOWN ISSUES TO PRE-EMPT (checklist — mark each fixed/mitigated/open)
Fingerprint (§9) · boot loop from AVB/vbmeta or FBE mismatch · keystore/KeyMint compat · data encryption after format · **IMEI/baseband loss from `nvdata`/`nvcfg` mount or SELinux problems** · modem/RIL version mismatch · VoLTE/IMS · Wi-Fi/BT firmware & module load order · GPS/AGPS · camera HAL3 + vendor tags + Camera2 API/RAW · audio amp (AW88194) firmware and call/BT audio · sensors calibration (`nvcfg`) · microSD detection · USB configfs/MTP/OTG · tethering/hotspot with eBPF · charging/health reporting · thermal throttling behavior · Assistant button mapping · Widevine level · Play Integrity (§9B) · EROFS vs ext4 · image size overflow · OOM during build · HDD slow-IO stalls (never "fix" by weakening the product).

---

## 15. FINAL RESPONSE FORMAT (when done or when truly blocked)
Short, plain, no marketing:
1. **Outcome:** tier achieved (T1/T2/T3), Android version, build type, file list with paths + SHA-256.
2. **Status table:** each hardware feature → VERIFIED / UNTESTED / KNOWN BROKEN.
3. **What the human must do next** (in order) and what to send back after the first boot.
4. **Biggest remaining risks** and the exact evidence behind them.
5. Time/disk used, and what you would do next with more time/space.

**START NOW:** read `STATE.md` if it exists; otherwise begin §4 (host + disk tier decision), then §5 (recon), §6 (research), §7 G0 (feasibility), and proceed through the tiers without waiting for approval. 
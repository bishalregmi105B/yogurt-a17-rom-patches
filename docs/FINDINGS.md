# FINDINGS — DerpFest for Micromax IN Note 1 (yogurt / E7746 / mt6768 Helio G85)

Compiled: 2026-10-25, from read-only device inspection (recon/), GitHub source reads, and
web research. Verdict scheme per master prompt §6: **REUSE / ADAPT / IGNORE**.
All claims are VERIFIED (static) unless marked UNTESTED.

## 1. Device ground truth (all VERIFIED on-device, recon/)

- Codename `yogurt`, model E7746, platform `mt6768` (Helio G85), board `k69v1_64`,
  flavor `full_k69v1_64-user` (pre-loop A/B=false).
- **Currently running**: DerpFest 13 OFFICIAL `13-Official-Tango-yogurt-20250213-1114`
  (works; includes working sensors/audio/etc). Bootloader state read from props;
  device is sideload/flash-capable once unlocked.
- Vendor identity: `Micromax/E7746/E7746:10/QP1A.190711.020/1620836268:user/release-keys`
  (Android **10 / Q**-class vendor), `ro.vndk.version=33` (community-set),
  `ro.vendor.api_level=29`, FCM **target-level=4** (= Q launch vendor),
  kernel FCM level 4 (`<kernel target-level="4"/>`).
- Kernel: **4.14.141-yogurt-v1.x**, clang r353983c1, `yogurt_defconfig`
  (kernel_config.txt). eBPF present subset:
  ON = BPF, BPF_SYSCALL, CGROUP_BPF, NETFILTER_XT_MATCH_BPF, NET_CLS_BPF,
  NET_SCH_INGRESS, PSI, BPF_EVENTS.
  **MISSING = BPF_JIT, NET_ACT_BPF** (G1 Phase-2 backport work).
  No EROFS, no FS_VERITY → **all images ext4**. F2FS + FS_ENCRYPTION available.
- Partitions: super = 9,126,805,504 B; group `micromax_dynamic_partitions` holds
  system+vendor+product ONLY (no system_ext/odm dynamic parts);
  boot 33,554,432; dtbo 8,388,608; recovery 33,554,432; vbmeta/vbmeta_system/vbmeta_vendor.
  Super image header: v2, base 0x40078000, pagesize 2048, ramdisk offset 0x07c08000,
  tags 0x0bc08000, cmdline `bootopt=64S3,32N2,64N2 buildvariant=user`, AVB flags 3.
- HAL inventory (full VINTF manifest + 10 scanned fragments under /vendor/etc/vintf):
  see §3 scoring below. Highlights: composer@2.1, keymaster@4.0 ("beanpod"),
  gatekeeper@1.0, camera.provider@2.4, audio/audio.effect@6.0, sensors@2.0,
  gnss@1.1+2.0, fingerprint = **android.hardware.biometrics.fingerprint@2.1 HIDL**
  (community-service) + vendor.focaltech.fingerprint@1.0,
  health@2.1 (community fragment), AIDL light (community), AIDL vibrator v2 (community),
  NN 1.3 mtk-gpu/mtk-neuron, cas@1.2, drm HIDL 1.4 widevine + AIDL clearkey,
  AIDL bluetooth.audio v2, MTK RIL: radio@1.2/1.4 + radio.config@1.1 + mtkradioex@1.9.

## 2. Branch-level facts (VERIFIED via Git reads)

| Target | Framework | Manifest | vendor/derp | Notes |
|---|---|---|---|---|
| DerpFest 16.2 | lineage-23.2 base, `android-16.0.0_r4` tag | DerpFest-AOSP manifest branch **16.2** | DerpFest-AOSP/android_vendor_derpfest @16.2; GMS = android_vendor_gms @ codeberg 16.2 | A16 QPR2 |
| DerpFest 17 | lineage-24.0 base, `android-17.0.0_r1` | branch **17** | DerpFest-AOSP pins @17; GMS = PixelOS proprietary_vendor_pixel_gms-17 | A17 stable since 2026-06 |

- DerpFest-AOSP/android_hardware_interfaces ships branches **16** and **17** only
  (no direct `16.2`; 16.2 targets LOS-23.2-era matrices which the A16.2 tree carries).
- DerpFest default.xml (16.2): revision refs/heads/lineage-23.2; remote github with
  review.lineageos.org; snippets: derp.xml (DerpFest repos), lineage.xml (LOS extras),
  kernel-6.{6,12,18}.xml (AOSP bazel kernel streams — ~20 GB; irrelevant to a 4.14
  prebuilt-kernel build but harmless; keep LEAN awareness).

## 3. FCM / VINTF scoring — THE CORE GATE-G2 RESULT (VERIFIED source reads)

Raw matrices captured at research/matrices/{23.2,24.0,df17}/ (all entries here are
required-at-level; note: on A16 the framework ships ONLY these levels; A17 has no
level-5 escape hatch):

| Matrix file | Installed on | Level meaning | Kernel configs demanded |
|---|---|---|---|
| compatibility_matrix.5.xml (295 B, **EMPTY**) | 23.2 (16.2) | Android 11 (R) FCM, retired deliberately: "kept to manage android11-5.4 kernel config reqs" | none (r_5.4 only for config chain) |
| compatibility_matrix.6.xml (full) | 23.2 (16.2) | Android 12 (S) launch | kernel_config_s_4.14/4.19/5.4/5.10 |
| compatibility_matrix.6.android17.xml | 23.2 (16.2) exported to 17 | S-FCM **extended for A17** (adds IRadio 1.6 slot1-3; keeps ISap 1.2, RadioConfig 1.1/1.3) | kernel_config_s_4.14/… |
| compatibility_matrix.7.xml (full) | both | Android 13 (T) launch | kernel_config_t_4.14/… |
| compatibility_matrix.8.xml | both | Android 14 (U) launch | kernel_config_u_5.15/6.1 (NO 4.14) |
| compatibility_matrix.202404.xml | both | Android 15 (V) | 6.1/6.6 |
| compatibility_matrix.202504.xml | both | Android 16 (B) | 6.12 |
| compatibility_matrix.202604.xml | 23.2 tree (STRUNK)/df17 | Android 17 (C) | 6.12 |
| compatibility_matrix.202704.xml | df17 only (future A18) | — | — |

- Levels ≤4 GONE from both trees (Los 23.2 + 24.0). The 4-er FCMs we currently use
  are unavailable → the vendor manifest **must** be re-declared at a supported level.
- **matrix.5 is literally empty** → declaring `target-level="5"` = zero required HALs.
  This is the *intended* R-vendor escape hatch on Android 16 and is what we do.
  Level 5 does NOT exist in the A17 file set (24.0 Android.bp: A17 set includes only
  5 absent) → this trick applies to **16.2 only**.
- matrix.6/6.android17/7 require (non-exhaustively) audio{6.0,7.x}, camera.provider
  2.4-7, keymaster 4.0-1, gatekeeper 1.0, composer 2.1-4, mapper 2.1/3,4,
  allocator 2.0/3/4, sensors HIDL 2.0-1, usb 1.0-3, wifi 1.3-6, provider-side
  health 2.1 (or AIDL), drm 1.3-4, media.omx 1.0, memtrack, gnss 2.0-, IRadio **1.5-6**
  for slot instances (M.7/6 require radio 1.5+ — we serve 1.2+1.4 → FAIL), power (AIDL
  2-3 at M.7 / AIDL 1-2 at M.6 — ours is HIDL 1.3 → FAIL), renderscript 1.0
  (M.6/7 yes; gone at 8), tetheroffload pair, authsecret, weaver, rebootescrow,
  atrace, thermal 2.0, nfc 1.2, and S-vendor-style AIDL suites.
- Practical read: to claim level 6/7 with the current vendor, the following are
  **shim work items** (framework/vendor-side, per §7-G2): IRadio 1.5/1.6 upgrade
  (PHH/PX-style radio shims or mt6768 radio), AIDL power, AIDL hostapd/supplicant,
  AIDL sensors, AIDL usb, composer AIDL removed at 8+ (keep level ≤7), AIDL audio
  (required at level ≥8 only — OK at 6/7), identity, weaver, rebootescrow, authsecret,
  power.stats, tetheroffload, boot 1.2 (bootctl—MTK bits exist), dumpstate, atrace.
- Therefore on A16.2 use `target-level="5"` (empty matrix; vintf static checks pass;
  runtime compatibility via preserved HIDL interfaces + community AIDL bridges where
  framework needs them: light/vibrator/NN/bt-audio are ALREADY community-AIDL ✓).

## 4. Kernel-level functions (G1)

- Phase 1 (prebuilt): use a known-bootable yogurt boot.img kernel+dtb+dtbo:
  the `13-Official-Tango-yogurt-20250213-1114` OTA (yogurt-devs held it; fallback =
  DerpFest SF/sourceforge mirror) - extract boot.img, cross-check with stock boot
  (identicals header/layout). (Blocker B2 — in progress.)
- Phase 2: rebuild from `SakthivelNadar/yogurt` (unified IN Note 1 / IN 1 kernel;
  branches android-10.0..15.0; default `yogurt-q-oss`). Add BPF_JIT+NET_ACT_BPF +
  pure Clang/LLD (needs a matching clang prebuilt: r353983c1 is proven for this tree).
- mt6768 sibling path (`mt6768-S`, 4.19 + S-vendor, A16/17 working on merlin/lancelot)
  requires a **Micromax-never-shipped S vendor** → ADAPT ideas only, not drop-in.

## 5. Ecosystem repos (verdicts)

| Source | Verdict | Use |
|---|---|---|
| yogurt-devs/android_device_micromax_yogurt (lineage-20.0/fourteen) | **REUSE as base** | BoardConfig/device.mk already derivative-correct; graft to 16.2; target level re-declared locally |
| yogurt-devs/android_vendor_micromax_yogurt (fourteen) | REUSE | blobs (VNDK 33 installed set on a working phone); regenerate manifest fragments |
| SakthivelNadar/yogurt (kernel android-14/apex) | REUSE Phase 2 | kernel-defconfig stable at 4.14 with backports |
| ArrowOS/android_device_mediatek_sepolicy_vndr (arrow-14.0) | REUSE | sepolicy base beside TARGET_USING_LEGACY_SELINUX |
| sarthakroy2002/clang-r353983c1 | REUSE Phase 2 | kernel toolchain |
| yogurt-devs/bootable_recovery (thirteen) | ADAPT (Phase 2) | don't ship; TWRP A13-era is too old for A16 OTA; build LOS-style recovery from tree |
| yogurt-devs/patches + their framework forks (frameworks_av/base/Bluetooth @ thirteen) | ADAPT | shows what yogurt needed patched for A13 (fingerprint etc.); port to 16.2 selectively |
| local_manifests/main/fourteen.xml | REUSE pattern | the recipe already folded into .repo/local_manifests/yogurt.xml |
| mt6768-S org (S-vendor A16/17 path) | IGNORE (source of ideas) | Non-matching ((our) vendor R-class, kernel 4.14) — do not copy drop-in |
| MisterZtr / TrebleDroid GSI lineage | ADAPT as Plan T3 + quirk reference | legacy-vendor audio/fingerprint/radio shim patterns |
| firmwarefile.com / filewale / mobifirmware (E7746 stock: SW_V12.0 070121, SW_V14.0 210513, SW_V17.0 221117) | USE for B1 (restore + blob cross-check) | hash everything; prefer V12.0 (matches running QP1A.190711.020 vendor-gen) |
| Mediatek-leaks/micromax_e7746_dump | ADAPT | cross-check blob list only; not a flashable zip |

## 6. Fingerprint (§9A) — what the community layers tell us

- Real implementation: HIDL `android.hardware.biometrics.fingerprint@2.1` served by
  community service (`fingerprint.mt6768.so` impl + vendor.focaltech.fingerprint@1.0
  co-serving; init service list on-device).
- Framework A16 accepts HIDL 2.1-3 fingerprint in the kept HIDL matrix entries —
  but IF the A16/A17 framework's FingerprintManager has a HIDL→AIDL bridging path we
  must confirm in-tree during bring-up (Phase P5) — look for
  `android.hardware.biometrics.fingerprint-…` translation / `Fingerprint21`.
- Keystore/Gatekeeper chain is the higher-probability enrollment blocker: keymaster@4.0
  HIDL + keymint AIDL bridging (km_compat / keymint AOSP path) must be validated in-tree.

## 7. Open blockers status

| # | Blocker | Path |
|---|---|---|
| B1 | Stock firmware zip + SHA-256 | firmwarefile.com VF12.0/V14/V17 candidates; hash everything |
| B2 | Known-good yogurt `boot.img` (Phase 1 kernel) | yogurt-devs/releases README/bin (build scripts; no zips) → Plan B: SourceForge/DerpFest SF release mirror; last resort: ship our own kernel from Phase-2 build |
| B3 | Branch lock | **DONE**: 16.2 locked (matrix.5 empty = R-vendor lane, kernel 4.14 is supported there by construction; LOS hardware stack known-compatible); 17 sprint possible AFTER a working 16.2 (so the trees are proven) — matches “newest that can pass gates” |

## 8. DF13 OTA (user-supplied zip, VERIFIED structurally, 2026-10-25)

- SHA-256 zip: 90c948bafb91fa00a724ba15098436f0df842148c99dab1f9281d06cacb64626
- Packaging class: **BLOCK recovery zip** (no payload.bin): system/vendor/product
  `.new.dat.br` + transfer lists + backuptool; boot/dtbo/vbmeta flashed by-name from
  `package_extract_file()` in updater-script ⇒ our 16.2 OTA should follow the SAME
  shape (A-only `bootdevice/by-name` convention, no A/B machinery).
- OTA metadata: post-sdk-level 33, SPL 2025-01-05, 2025-02-13 build,
  pre-device E7746,E6746,yogurt; post-build spoof sailfish:9 (community convention).
- Dynamic partitions op list: group micromax_dynamic_partitions 9,122,611,200 B;
  system 1,473,798,144 / vendor 551,792,640 / product 1,746,653,184 → G4 anchors.
- boot.img header v2 (extracted, hashed): kernel 9,711,327 B @0x40080000,
  ramdisk 1,219,454 B @0x47c80000, tags 0x4bc80000, page 2048,
  cmdline `bootopt=64S3,32N2,64N2 buildvariant=user buildvariant=user` (doubled
  'buildvariant=user' — carry-or-clean decision tracked in STATE.md),
  header_size 1660, dtb embedded.
- REUSE verdict: boot.img = Phase-1 prebuilt kernel source (proven bootable);
  vbmeta.img = reference for our disabled-verity replacement (this one is the
  DF13-signed one, verity-aware); recovery.img = proven-by-boot reference only
  (we must build lineage-style recovery for 16.2 per §8).

## 9. Stock V12.0 zip + scatter (VERIFIED, CRC-clean, 2026-10-25)

- CRC: `unzip -t` → "No errors detected"; 45 files; SHA verified twice
  (f0affe0b2e2246da7bfc1b6d1dfc0684ccd76942f2bd137e9f46f95e0af55e1d).
- Scatter facts (k69v1_64, EMMC): recovery 32 MiB, boot 32 MiB, dtbo 8 MiB,
  vbmeta(+system+vendor) 8 MiB each, super **0x100000000 (4 GiB) ← DIFFERS from
  the device-true 0x21FF00000 (8.5 GiB)**, cache 432 MiB, userdata 3 GiB,
  nvram 64 MiB, nvdata 64 MiB, persist 48 MiB, nvcfg 32 MiB, metadata 32 MiB,
  md1img 128 MiB, tee1 5 MiB + tee2 12 MiB, gz1/2 16 MiB each, lk/lk2 2 MiB.
- ⇒ Scatter is NOT authoritative for this unit's partition table; G4 anchors stay
  = recon lpdump (9,126,805,504 B) + DF13 op-list group budget.
  SP Flash Tool: Download-Only only. Never Format/PGPT rewrite with this scatter.
- Contents of value: stock boot.img + boot-debug.img + vmlinux (231 MB, symbols —
  Phase-2 kernel config cross-check source), stock vbmeta trio (4 KiB each),
  full MTK firmware set (preloader/lk/md1img/scp/sspm/spmfw/tee), APDB/MDDB,
  googlekey/* (NOT extracted — sensitive; stays sealed in zip).
- Extracted refs (small set, hashed): downloads/stock_v12_ref/ (scatter,
  Checksum.ini, boot.img, dtbo-verified.img, recovery.img, vbmeta{,_system,_vendor}).

## 10. LIVE AUDIT on the running ROM (user's device, 2026-10-25 11:58, VERIFIED)

All files in `recon/live_audit/` (fp_props.txt, crash_buffer.txt, camdump_full.txt,
cam_parse.json). This is a read-only audit; nothing was pushed or reset.

### 10a. Fingerprint root cause — LOST to sepolicy, NOT hardware

- init service: `vendor.fingerprint_hal` = `/vendor/bin/hw/
  android.hardware.biometrics.fingerprint@2.1-service.yogurt`,
  class hal, user system, `seclabel u:r:hal_fingerprint_default:s0`,
  writepid foreground — rc is CORRECT.
- sys props: `sys.init.updatable_crashing=1`,
  `sys.init.updatable_crashing_process_name=vendor.fingerprint_hal`
  → crash-loops every ~5 s (2 tombstones back-to-back).
- Exact abort line (tombstone via logcat -b crash):
  `Abort message: 'Binder driver '/dev/vndbinder' could not be opened. Terminating:
  Using /dev/vndbinder failed: unable to mmap transaction memory.'`
- Crash stack: `fingerprint.mt6768.so (`FID pattern pc 67184`) →
  `ProcessState::init` (vndk-v33 libbinder) → `__android_log_assert` → `abort`.
- Preceding SELinux denials (auditd, Enforcing):
  1. `avc denied { open } /data/vendor/focaltech/ff_config.dat` (and
     `ff_statistics.dat`) — scontext `hal_fingerprint_default`, tcontext
     `vendor_data_file`
  2. `avc denied { map } /dev/vndbinder` — hal_fingerprint_default ← THE ABORT
  3. `avc denied { create } netlink_kobject_uevent_socket` — hal_fingerprint_default
     → app HAL log: `device_irq_thread: socket() = Permission denied`
- Framework stack alive and correct: Fingerprint21 (HIDL 2.1 bridge) does the right
  retry loop + `ctl.interface_start` kick — it just never sees a live daemon.
- ⇒ FIX (all in-tree, no vendor edits):
  a. sepolicy grants for `hal_fingerprint_default`:
     vndbinder open/read/write/map + binder call transfers, vendor_data_file
     open/read/write/create (+ dirs), netlink_kobject_uevent_socket
     create/read/write/bind, (+ neverallow-safe).
  b. dedicated file_contexts: `/data/vendor/focaltech(/.*)?` → a typed
     `focaltech_data_file` + allow, or grant vendor_data_file ops (type strategy in
     tree, filetrans so existing files relabel on boot).
  c. keep rc/init unchanged; verify via boot check: `getprop
     sys.init.updatable_crashing` must be EMPTY and `lshal | grep fingerprint`
     must list 2.1 + focaltech@1.0.
- Confidence: HIGH (exact abort message captured; this is the §9.4 class).

### 10b. Camera ground truth (Device 0 = main, FULL level)

| aspect | VERIFIED reading |
|---|---|
| HAL | camera provider 2.5 remote; HAL device v3.5 |
| devices | 6 total; 4 public (0,1,3,4). 0 = main back 48 MP quad-Bayer (flash, 90°, active array 4000×3000 = binned 12 MP output); 1 = front 16 MP (4656×3496); 2/4 = 2 MP depth/macro (1600×1200); 3 = 5 MP (2560×1920); 5 = LOGICAL_MULTI_CAMERA hosting the MTK remosaic control |
| main-sensor 48 MP path | **VERIFIED**: MTK vendor control `0x800b0006 remosaicenable` (com.mediatek.control.capture) present in the HAL characteristics of the logical composite → 48 MP stills ride the stock/proprietary remosaic pipeline; the phone does NOT expose 8000×6000 as a standard Camera2 stream size — apps get 48 MP shots via the vendor control, as on stock Micromax |
| hardware level | FULL (all cameras) |
| capabilities | BACKWARD_COMPATIBLE, MANUAL_SENSOR, MANUAL_POST_PROCESSING, READ_SENSOR_SETTINGS, RAW, BURST_CAPTURE; main also CONSTRAINED_HIGH_SPEED_VIDEO |
| AE fps ranges (main) | [10..10 15..15 15..20 5..30] → ceiling 30 fps |
| high-speed video | 1080p modes marked up to 120 fps; 720p high-speed entry; NO 4K high-speed bucket |
| stabilization | video stabilization modes [0 1] (=MODES_OFF/MODES_ON) present |
| edge modes | OFF/FAST/HIGH_QUALITY |
| postRawSensitivityBoost | [100..100] (no boost range) |

Verdicts spec-aligned:
- **All five cameras match Micromax's advertised hardware** (48 MP quad-Bayer main,
  16 MP front, 5 MP, 2×2 MP); the main sensor's 12 MP reading in HAL tables is the
  standard binned active array, with the 48 MP still path reachable through MTK's
  `remosaicenable` vendor control (kept in-tree, plus a cheap camera hint if the
  DerpFest camera app needs it).
- 4K 3840×2160 stream configs exist on main+front for JPEG/YUV/RAW10/YV12 →
  **4K30 recording supported (stock HAL)**.
- **4K60: NOT achievable** — sensor AE table + high-speed tables cap at 30 fps
  (only 1080p reaches 120). Any ROM claiming 4K60 on this hardware is lying.
- 1080p120 high-speed (slow-mo) and RAW/BURST manual capture are REAL and will be
  preserved + exposed in the DerpFest camera/pro mode path.
- "iOS-level processing": Apple's ISP stack is not portable; what we deliver =
  keep ALL stock ISP modes (edge/denoise HIGH_QUALITY, remosaic 48 MP stills),
  never strip the vendor pipeline, expose manual controls + RAW; the most
  "processing" that is honestly possible on this hardware.

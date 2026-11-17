# Optimisation + AI Plan (IN Note 1, 4 GB, Helio G85)

## Measured device state (2026-11-01)
- MemTotal 3.85 GB, MemAvailable ~0.74 GB under load, Mlocked 309 MB.
- RAM extension (zram) IS ON: swap ~2.75 GB (fstab `zramsize=75%`, lz4, 8 streams), ~450 MB used.
- Effective swappiness was **150**: `init.ago.rc` post-fs-data overrides the 60 set in `init.mt6768.rc`.
- Biggest RSS: system_server 635 MB, Photos 452 MB, SystemUI 323 MB, GMS 315 MB + gms.unstable 200 MB.
- lmkd already uses the new strategy (`ro.lmk.use_new_strategy`, `kill_heaviest_task`, `downgrade_pressure=60`).

## Applied
- `init.ago.rc`: swappiness 150 -> 100 (global + memcg). Reason: community guidance for 4 GB devices is 40-100. 150 pushes pages into zram too early and costs CPU on A55 cores.

## Next, in order (each needs an on-device A/B, so do one per build)
1. lmkd PSI: try `ro.lmk.psi_partial_stall_ms=70` / `psi_complete_stall_ms=700`. Compare background-app survival and jank.
2. zram: keep 75% (about 2.9 GB) with lz4. zstd compresses better but costs CPU. Only test it if the kernel lists zstd in `comp_algorithm`.
3. Trim resident system services: disable unused GMS / adservices / DeviceAsWebcam / cellbroadcast background processes (each 90-100 MB RSS).
4. ART: `dalvik.vm.heapgrowthlimit` 384m is generous for 4 GB. Test 256m.
5. Reduce mlocked memory by reviewing `pinner` config (PinnerService pins launcher/camera files).
6. Optional: a kernel-level `mem_boost` / `vm.watermark_scale_factor` tweak (kernel rebuild, so later).

## AI features (open source, no Google proprietary AICore)
- On-device LLM apps: PocketPal AI, MLC Chat, llama.cpp via Termux. 4 GB RAM limits this to ~1B-class quantised models.
- Open-source ROM-level ideas: system-wide voice/text assistant that routes to a user-chosen local or cloud endpoint, smart replies via local model, OCR/translate via ML Kit-free Tesseract/Bergamot.
- The Extra Button (now implemented in PhoneWindowManager, long press = app picker) can launch any of these.
- Gemini Nano / AICore needs Tensor/NPU-certified hardware, so it will not work on a G85.

## Not doing
- Spoofing as Pixel 10 Pro to claim Pixel-purchase offers (Google AI Pro trial, Photos perks). Those are tied to purchased hardware, so I won't build it.
  The existing certified-fingerprint spoof is only for Play Integrity attestation.

## Swap / RAM extension research (kernel 4.14.141)
Kernel config on device: ZRAM=y, ZSMALLOC=y, lz4 only. NOT present: ZRAM_WRITEBACK, ZSTD, FRONTSWAP/zswap.
- **Applied:** zram 75% -> 100% (about 3.7 GB) in `fstab.mt6768`. Community consensus is 100-125% max on 4.14. Above that, the compressed pool (about 1/3 of stored data) starves foreground RAM and causes thrashing.
- **Flash swap file on /data: not viable.** /data is f2fs and 4.14 f2fs has no swapfile support (added in 4.19). A loop-device workaround risks deadlock under memory pressure and wears the eMMC, so not recommended.
- **Real "more memory" option:** kernel rebuild with `CONFIG_ZRAM_WRITEBACK=y` (+ optional ZSTD) so cold/incompressible pages go to a flash backing device. Needs a kernel build and a loop/partition backing store; a separate, larger task.
- Compression: lz4 stays (zstd not compiled in).

## DEFERRED: kernel rebuild (do later, after the ROM build)
Goal: real "RAM extension" via zram writeback + better compression.
1. `yogurt_defconfig`: `CONFIG_ZRAM_WRITEBACK=y`, `CONFIG_ZRAM_MEMORY_TRACKING=y` (idle-page marking).
2. Optional: `CONFIG_CRYPTO_ZSTD=y` (check 4.14 zram supports it; backport if not), `CONFIG_CRYPTO_LZ4HC`.
3. Backing store: loop device on a /data file (f2fs OK for loop) or a spare partition. Set `backing_dev` before `disksize` in init.
4. Userspace: init service that marks idle pages and writes back sparingly (flash wear), incompressible `huge` pages first.
5. Re-test: swappiness, PSI thresholds, thrash behaviour, eMMC write volume.
Risk: needs a kernel build + boot.img/vendor_boot repack and a flash test; keep the current prebuilt kernel as fallback.

## Status update (applied, staged in git, NOT yet built/tested)
| Change | File | Value |
|---|---|---|
| zram size | fstab.mt6768 | 75% -> 100% (measured ratio ~4:1, 427 MB data in 106 MB RAM, so cheap) |
| swappiness | init.ago.rc | 150 -> 100 |
| lmkd PSI partial stall | vendor.prop | ro.lmk.psi_partial_stall_ms=120 |
| lmkd thrashing limit | vendor.prop | ro.lmk.thrashing_limit=50 |
| lmkd swap-free low | vendor.prop | ro.lmk.swap_free_low_percentage=15 |
| cached process cap | overlay config.xml | config_customizedMaxCachedProcesses 1024 -> 32 (86 process records seen) |
| Extra Button | PhoneWindowManager.java | KEY_MOVE_HOME: short = launch chosen app, long = pick app |

Source for lmkd values: AOSP lmkd docs + community 4 GB guidance (partial stall 100-150, thrashing 50-60, swap-free 15).

### Deliberately not changed
- ART heap (`heapgrowthlimit`): device runs 192m (system value overrides vendor.prop); no evidence it limits anything. Leave.
- Disabling system packages (adservices, DeviceAsWebcam, cellbroadcast): mainline modules / hard to remove safely; they are idle-cheap. Revisit after measuring on the new build.
- Bundling AI apps / Gemini Nano: AICore needs Tensor/NPU hardware. Install open-source apps (PocketPal AI, MLC Chat) from F-Droid/GitHub by the user instead.
- Pixel 10 Pro identity for Photos/AI Pro offers: not implemented. Those offers depend on purchased hardware.

### Verify after flashing
`adb shell getprop ro.lmk.psi_partial_stall_ms`, `dumpsys meminfo` (ZRAM line, swap total about 3.7 GB), `dumpsys activity | grep CUR_MAX_CACHED` (expect 32), long-press the assistant button.

## Kernel upgrade strategy (decided: stay on 4.14, backport + retune; do NOT jump to 4.19)
Why not 4.19: MediaTek GPU/camera/modem/display blobs are built against 4.14 symbols and structs; MT6768 has no vendor 4.19 BSP. A jump bootloops.

Audit of current yogurt_defconfig / device (2026-11-01):
- Already good: schedutil default governor, PSI, UCLAMP, SCHED_TUNE, f2fs, CC_OPTIMIZE_FOR_PERFORMANCE.
- Missing / weak, in priority order:
  1. `CONFIG_ZRAM_WRITEBACK` + `ZRAM_MEMORY_TRACKING` (memory extension)
  2. TCP congestion: default is **bic** (only bic/reno/cubic built). Enable `TCP_CONG_BBR` + `NET_SCH_FQ`, set default bbr (or cubic). Safe, small win for Wi-Fi/data.
  3. I/O scheduler: default **cfq** on eMMC. Switch default to deadline (or add BFQ backport; `MQ_IOSCHED_KYBER` exists but single-queue eMMC uses legacy path).
  4. Compression: add zstd lib backport (medium effort) and test zram zstd vs lz4; lz4 -> lz4 1.9 optional.
  5. `CONFIG_MTK_SCHED_EAS_POWER_SUPPORT` is off: check it is intentionally off before touching.
  6. Optional: `KSM` off is correct for 4 GB (CPU cost); keep. THP off: keep.
  7. Out of scope for a ROM that wants Play Integrity: KernelSU/root.
- Toolchain: BoardConfig wants clang r353983c1 (absent). Try gcc-4.9 (present) or old-clang-compatible flags first; clang 20 will need source fixes.

Recommended order of work (each step boots and is verified before the next):
 1. Get stock source to build to an identical-behaving Image.gz-dtb (proves toolchain). Keep prebuilt as fallback.
 2. Add BBR/FQ + deadline I/O (trivial config-only wins).
 3. Add zram writeback + init service + backing store.
 4. Try zstd backport.
Estimated: step 1 = 1-3 h (toolchain), steps 2-3 = 1-2 h each, step 4 = 1-2 h.

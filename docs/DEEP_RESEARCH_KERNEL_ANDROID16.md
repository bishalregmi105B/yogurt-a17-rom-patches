# Deep research: kernel-locked + Android 16 tweaks + collaboration (IN Note 1, MT6768, kernel 4.14.141)

Confidence tags: **[V]** verified on the device or in our source tree, **[R]** from web research (summaries, not primary sources; treat as leads and test before trusting).

## A. Measured facts about this device [V]
| Item | Finding | Meaning |
|---|---|---|
| Display | One mode only: 1080x2400 @ 60 Hz, no HDR | No 90 Hz. A panel mode needs DDIC/panel-driver timings in the kernel; the panel is a 60 Hz part. Not realistic. |
| GPU / renderer | Mali-G52 MC2, `vulkan.level=1` (Vulkan 1.1) exposed, HWUI = Skia **OpenGL** | Keep skiagl. skiavk is a risky experiment (see C). |
| Cached app freezer | `use_freezer=false` | Framework default is true, so the **kernel** is why it is off (see B1). Biggest locked feature. |
| Cached processes | cap was 1024, 86 process records | Set to 32 (staged). |
| zram | lz4, ~4:1 ratio, 100% size staged | Cheap, fine. |
| ART | `speed-profile` bg-dexopt, `verify` after OTA, zygote64_32, preloaded-classes present | Already sane. |
| Widevine | HAL present (drm 1.0-1.2 widevine + clearkey) | Level (L1/L3) not yet checked; verify with a DRM Info app. |
| Charging | `ro.vendor.mtk_pe_support` present (MTK Pump Express); phone was plugged at 100% | Cannot judge speed; test at low battery with the stock charger. |
| Camera | `camera.level.full`, manual sensor, RAW capability | Hardware is capable; unlocks Aperture manual controls and GCam ports. |
| Thermal | `thermal.conf` and `thermal.off.conf` in vendor | Thermal policy is a vendor file we can tune. |
| CPU | little 500 MHz-1.8 GHz, big 850 MHz-2.0 GHz, schedutil | Fine. |

### Baseline of the CURRENT build (`research/bench/20261101_130438_baseline_current_build.txt`) [V]
- RAM: MemAvailable 1.2 GB (idle-ish), 98 process records, cached cap 1024, swap 2.75 GB (before our staged changes), 0 lmkd kills since boot.
- Cold start (ms): Settings 927/577/607, Aperture 552/496/513, Photos 587/318/313, Play Store 785/233/483.
- **Launcher jank: 11.4% janky frames (29% by the legacy metric); p50 15 ms, p90 46 ms, p95 61 ms.** This is the clearest thing to improve and the number to beat after each change. Next step is a Perfetto trace of the launcher to see if it is app-side, SurfaceFlinger-side or GPU-side before tuning anything.
- Note: `ro.build.fingerprint` reads the stock Micromax Android 10 string while the ROM is 16. Looks deliberate from earlier work, but confirm it is intended.

## B. Kernel-locked features that the hardware supports (ranked)
1. **Cached app freezer** [V]. Needs binder freeze support (absent in `drivers/android/binder.c`) and the cgroup v2 freezer (`cgroup.freeze`, mainline 5.2+; 4.14 only has the v1 `CONFIG_CGROUP_FREEZER`). Backporting both is real work (binder freeze patches from Android common kernel + cgroup2 freezer) but is the **single best RAM win**: frozen cached apps stop using CPU and stop being killed as often. High effort, high value. Later phase.
2. **zram writeback + zstd** [V]. Config off / not built. Medium effort. (Already in plan.)
3. **BBR + FQ** [V]. Default TCP is `bic`. Config-only.
4. **I/O scheduler** [V]. Default `cfq` on eMMC. Config-only (deadline) or BFQ backport.
5. **MTK EAS power support** [V]. `CONFIG_MTK_SCHED_EAS_POWER_SUPPORT` is off. Find out why before touching; wrong values hurt battery.
6. **Camera features** [V]. Hardware ok; the work is in HAL/params (Aperture MtkRequestOptions already staged).
7. Not realistic: 90 Hz panel, kernel 4.19 (blobs are 4.14-ABI) [R].

## C. Android 16 ROM tweaks (userspace, no kernel)
Do now / low risk:
- **Done (staged):** lmkd PSI, thrashing, swap-free, cached-process cap, zram 100%, swappiness 100.
- **Bluetooth LDAC** [R]: AOSP ships LDAC encode; verify it is offered for BT headphones (`dumpsys bluetooth_manager | grep -i codec`). Free quality win if present.
- **Blur** [R]: window blur is expensive on Mali-G52. Check whether blur is on by default for this device; a default-off overlay is a cheap smoothness gain. Verify before changing.
- **Benchmark first:** `scripts/bench.sh` (new) records RAM, process count, cold-start times and launcher jank. Run it before and after each change.

Treat with suspicion:
- `debug.hwui.texture_cache_size` and friends [R]: web guides push these, but they only matter for the legacy GL pipeline, not Skia. Likely **no effect**; skipped.
- Forcing `skiavk` [R]: the web agrees it is unstable on Mali-G52 vendor drivers (surface flicker, shader stalls). Only try with Perfetto traces and a recovery plan.
- Hand-disabling mainline modules (adservices etc.): small RAM, real breakage risk. Skipped.

Medium effort:
- **Phantom process / child-process limits** [R]: relax if background utility apps get killed.
- **Doze / standby tuning**, `persist` freezer-like behaviour via lmkd + app standby buckets.
- **Perfetto jank tracing** on real use (launcher, Photos, TikTok) to find where frames are lost before tuning blindly.

## D. Ideas from other ROM communities [R]
- crDroid: broad settings surface, long-term stability focus. Evolution X: Pixel-style features, Circle-to-Search hooks (needs Google app + Pixel fingerprint spoof, which we already have only for Play Integrity). DerpFest: hardware controls and QS. AxionOS: fluid-UI performance focus.
- On-device AI on ROMs is done with **user-space open-source apps** (PocketPal AI, MLC Chat, llama.cpp), not system AICore. Our Extra Button can launch them.
- Search leads for kernel ideas: GitHub repos for other MT6768 4.14 devices (Redmi Note 9 / Realme C3 / Narzo 10 class). They carry BBR, zram tweaks, I/O scheduler picks and f2fs tweaks we can **cherry-pick** instead of writing from scratch. KernelSU is out of scope (conflicts with Play Integrity).

## E. Collaboration + workflow (what actually makes this faster)
1. **Commit everything now.** We have staged/uncommitted edits across `frameworks/base`, `device/micromax/yogurt`, `vendor/micromax/yogurt`, `packages/apps/Aperture`, `frameworks/native`, `system/sepolicy`. One bad `repo sync` loses them. Put each on a local branch with real commits.
2. **Export our framework changes as patches** (`git format-patch` into `patches/`), so moving to a newer ROM revision is a re-apply, not a re-do.
3. **A `local_manifests/` file** listing our device, vendor, kernel and Aperture forks so anyone can `repo sync` the exact tree. Matches the community template.
4. **Kernel CI on GitHub Actions** [R]: kernel-only builds fit on free runners (full AOSP does not). That frees this HDD machine and gives one-click test kernels. Needs the source in a GitHub repo.
5. **Faster local builds** [V]: `/mnt/rombuild` is on a spinning disk. Moving `out/` (or the whole tree) to an SSD is the biggest speed-up available, bigger than any flag. `ccache` is at 15 GB; 30-40 GB is affordable (77 GB free).
6. **Measure, one change per build, keep a changelog** (this folder + `bench/`). Telegram/XDA testers should be asked for a logcat + last-kmsg with every bug, as the community guidance says.
7. Share upstream: the MMS HAL `.rc` fix, the HEVC-alignment fix and the extra-button work are useful to other IN Note 1 / MT6768 users.

## F. Proposed phases
| Phase | Work | Needs kernel? |
|---|---|---|
| 1 (now) | Final ROM build with staged tuning, run `bench.sh` before/after | No |
| 2 | Commit + patches + manifest; BT LDAC and blur checks; Perfetto on real jank | No |
| 3 | Kernel: toolchain proof, BBR/FQ, deadline, zram writeback | Yes |
| 4 | Kernel: zstd, then the big one, cached app freezer backport | Yes |
| 5 | Charging, thermal.conf, camera tuning with measured results | Partly |

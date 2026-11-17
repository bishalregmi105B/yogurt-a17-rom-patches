# Deep Log Analysis & Kernel 4.14 Optimization Audit (Micromax IN Note 1 / MT6768, DerpFest 17)

**Target Device:** Micromax IN Note 1 (`E7746` / `yogurt`, `MT6768` 2× Cortex-A75 @ 2.0 GHz + 6× Cortex-A55 @ 1.8 GHz, Mali-G52 MC2 `r20p0`, ~3.85 GB usable RAM, eMMC)  
**Kernel:** `4.14.141-yogurt-v1.x` (`PREEMPT`, `HZ=300`, `PSI=y`, `UCLAMP=y`, `SCHED_TUNE=y`, `TCP_CONG_BBR=y`, `ZRAM=y`)

---

## Part 1: Deep Live Log & Runtime State Findings

### A. Active Logcat Errors & Root Causes (`main`, `system`, `events`, `crash`, `radio`)

| Count | Tag & Error | Root Cause (Verified in Source / Runtime) | Severity & Action |
|---:|---|---|---|
| **799** | `E/SystemServiceRegistry: Manager wrapper not available: obscura` | [SystemServiceRegistry.java](file:///mnt/rombuild/frameworks/base/core/java/android/app/SystemServiceRegistry.java#L1057-L1065) registers `Context.OBSCURA_SERVICE`, while SEPolicy (`system_app.te:29`, `platform_app.te:31`) only allows `system_app` and `platform_app` to `find` `obscura_service`. Unprivileged/priv apps querying system services get `null` and spam logcat. | **Medium (Log spam / Binder overhead)** — Fix `SystemServiceRegistry` null/availability guard or SEPolicy visibility depending on intended callers. |
| **148 / 126 / 40** | `E/beanpodkeymaster` (cmd `64`, err `-1000`), `E/KeyboxChainGenerator` (`Keybox has no EC certificate`), `E/keystore2` | Beanpod Keymaster hardware attestation command 64 returns `-1000`, and [KeyboxChainGenerator.java](file:///mnt/rombuild/frameworks/base/core/java/com/android/internal/util/KeyboxChainGenerator.java#L153-L165) throws `IllegalStateException: Keybox has no EC certificate` during `AttestationService` fallback. | **Medium (Play Integrity / Keystore spam)** — Provide a valid EC+RSA keybox or guard fallback when EC cert is absent. |
| **44 / 43** | `E/chromium: tile memory limits exceeded`, `E/ashmem: readlink(/proc/self/fd/...) failed: Operation not permitted` | Android WebView/Chromium sandboxed renderers (`dumpable=0` + seccomp) call `readlink("/proc/self/fd/N")` in `libcutils/ashmem-dev.cpp` to detect `memfd`, which is blocked by `EPERM`. `CONFIG_ASHMEM=y` is enabled, but `memfd` detection triggers the fallback error. | **Medium (WebView perf & spam)** — Patch `system/core/libcutils/ashmem-dev.cpp` `is_memfd_fd()` to probe `fcntl(fd, F_GET_SEALS) >= 0` instead of `readlink(/proc/self/fd/...)`. |
| **31–32** | `E/NativeTombstoneManager: Tombstone's UID (1000) not an app, ignoring` + `/data/tombstones/tombstone_11..15` | Inspected `tombstone_14` & `tombstone_15`: `/vendor/bin/volte_imcb` (`uid 1000`) exited on `signal 15 (SIGTERM)` (`SI_USER` / `SI_QUEUE` from `pid 1`) during shutdown/restart; `tombstone_00..10, 16..31` are historical pre-fix `com.google.android.gms.ui` crashes. | **Low** — Not an active SIGSEGV crash; prune stale `/data/tombstones` if testing cleanly. |
| **19** | `E/BootReceiver: Could not open /sys/kernel/tracing/instances/bootreceiver/trace_pipe: ENOENT` | Android `BootReceiver` looks for `/sys/kernel/tracing/instances/bootreceiver/trace_pipe`, which does not exist on this kernel/init setup. | **Low (Harmless boot noise)** |
| **13 + 13** | `E/system_server: Unable to access: /sys/kernel/dmabuf/buffers` & `/sys/fs/bpf/dmabuf/prog_dmabufIter_iter_dmabuf` | Kernel `4.14.141` lacks `CONFIG_DMABUF_SYSFS_STATS` and modern BPF `dmabufIter`, which also causes `dumpsys meminfo` footer to compute `GPU: 0K (-99,492K dmabuf + 99,492K private)` even though per-process `GL mtrack` (`99,492K`) works via AIDL `IMemtrack`. | **Low / Informative** |
| **6** | `E/VibratorInfo: Invalid frequency profile received from HAL` | [Vibrator.cpp](file:///mnt/rombuild/device/micromax/yogurt/vibrator/Vibrator.cpp#L114-L149) returns `EX_UNSUPPORTED_OPERATION` for resonant frequency / Q-factor / bandwidth map (hardware is an ERM motor without LRA frequency control). | **Low (Expected on ERM)** |
| **1–2** | `E/SensorService: Failed to addFrozenStateChangeCallback, error=-38` (`ENOSYS`) | [SensorService.cpp](file:///mnt/rombuild/frameworks/native/services/sensorservice/SensorService.cpp#L2009-L2016) tries to register Binder frozen-state callbacks for `suspend_sensor_event_delivery_on_frozen_pid`, which requires Linux 5.2+ cgroup v2 `freezer`. Kernel `4.14.141` only has cgroup v1 `freezer`. | **Medium (Cached App Freezer)** — See Tier 3 backport option or disable the flag on 4.14. |
| **Misc** | `E/MTK_FG: init failed, return!`, `E/RILJ` (5G NR calls on `VOICE < 2.0`), `E/RilRatcheter`, `E/AppOps: attributionTag VCN` | `cwfg_gauge` / `fuelgauged` minor init log; Android 17 Telephony probing NR/VoNr APIs unsupported by 4G MT6768 RIL; framework VCN attribution warning. | **Low** |

---

### B. Critical Silent Configuration & Kernel Bottlenecks Found

1. **`schedutil` Rate-Limit Tuning Silently Fails at Boot!**
   - [init.mt6768.rc](file:///mnt/rombuild/device/micromax/yogurt/rootdir/etc/init.mt6768.rc#L923-L929) and [init.ago.rc](file:///mnt/rombuild/device/micromax/yogurt/rootdir/etc/init.ago.rc#L21-L25) write to:
     `/sys/devices/system/cpu/cpufreq/policy0/schedutil/{up,down}_rate_limit_us` and `policy6/schedutil/...`
   - **Live reality**: [mtk_cpufreq_main.c](file:///mnt/rombuild/kernel/micromax/yogurt/drivers/misc/mediatek/base/power/cpufreq_v1/src/mtk_cpufreq_main.c#L1383-L1392) omits `CPUFREQ_HAVE_GOVERNOR_PER_POLICY` in `_mt_cpufreq_driver.flags`. As a result, [cpufreq_schedutil.c](file:///mnt/rombuild/kernel/micromax/yogurt/kernel/sched/cpufreq_schedutil.c#L812-L814) creates **one global** directory `/sys/devices/system/cpu/cpufreq/schedutil/`, NOT per-policy folders!
   - **Measured impact**: All 8 init writes fail with `ENOENT`, leaving **both** clusters at **`up_rate_limit_us = 1000` / `down_rate_limit_us = 1000`** (`1 ms`). Dropping frequencies after `1 ms` causes rapid OPP ping-pong during 60Hz scrolling (stutters + unnecessary DVFS transitions).

2. **Permanent Always-On Boost Hurting Battery & Thermals**
   - [init.mt6768.rc](file:///mnt/rombuild/device/micromax/yogurt/rootdir/etc/init.mt6768.rc#L902-L921) hardcodes at `sys.boot_completed=1`:
     - `perfserv_ta_boost 15`
     - `perfserv_fg_boost 10`
     - `/dev/stune/top-app/schedtune.boost 10`
     - `/sys/module/ged/parameters/gx_force_cpu_boost 1`
   - Meanwhile, [powercontable.xml](file:///mnt/rombuild/device/micromax/yogurt/configs/power/powercontable.xml#L26-L52) expects `DefaultValue = 0` for `gx_force_cpu_boost`, `perfserv_ta_boost`, and `schedtune.boost` so boosts are transient on touch/launch/rendering ([powerscntbl.xml](file:///mnt/rombuild/device/micromax/yogurt/configs/power/powerscntbl.xml#L3-L39)). Keeping `gx_force_cpu_boost = 1` ([ged_kpi.c](file:///mnt/rombuild/kernel/micromax/yogurt/drivers/misc/mediatek/gpu/ged/src/ged_kpi.c#L1307-L1331)) + `ta_boost = 15` forces continuous CPU boosting on every GPU frame even when idle or reading text.

3. **Memory Reclaim Stalls (`zstd` level 3 + Reclaim Params + No `MEMCG`)**
   - Live `/proc/vmstat` at **45s uptime**: `allocstall_normal = 14`, `allocstall_movable = 33`, **`pgscan_direct = 12916`**, `pgsteal_direct = 3061` (with `MemTotal = 3847732 kB`, ZRAM `2308632 kB`, `SwapFree = 2289432 kB`).
   - Why direct reclaim fires immediately:
     - [crypto/zstd.c](file:///mnt/rombuild/kernel/micromax/yogurt/crypto/zstd.c#L26) uses **`#define ZSTD_DEF_LEVEL 3`**, which has ~3–5× higher CPU cost per 4KB page than `lz4` or `zstd` level 1 on Cortex-A55/A75 cores.
     - `init.mt6768.rc:116-117` writes `lz4` then immediately overwrites it with `zstd`.
     - `# CONFIG_MEMCG is not set` in `.config`, yet [init.ago.rc](file:///mnt/rombuild/device/micromax/yogurt/rootdir/etc/init.ago.rc#L16-L18) attempts to write `/dev/memcg/.../memory.swappiness`. Also `watermark_scale_factor = 150` increases background reclaim aggressiveness earlier than default (`10`).

4. **Suboptimal Scheduler, Power & Suspend Settings**
   - **`CONFIG_PELT_UTIL_HALFLIFE_32=y`**: 32ms PELT utilization half-life reacts slower to 16.6ms (60Hz) touch/animation bursts than `CONFIG_PELT_UTIL_HALFLIFE_16=y`.
   - **`write /sys/power/pm_async 0`** (`init.mt6768.rc:653`) disables asynchronous parallel driver suspend/resume, lengthening wakeup/sleep latency.
   - **`write /sys/kernel/rcu_expedited 1`** (`init.mt6768.rc:54`) stays enabled post-boot; keeping expedited RCU during idle increases IPIs and CPU wakeups (AOSP best practice is `1` at boot, `0` on `sys.boot_completed=1`).

---

## Part 2: Deep Kernel & System Optimization Roadmap (MT6768 / 4.14.141)

### Tier 1 — High-ROI, Low-Risk Kernel & Init Optimizations (Immediate)

#### 1. CPU & EAS (`schedutil` + PELT + PowerHAL)
- **Expose per-policy `schedutil` in kernel**: Add `CPUFREQ_HAVE_GOVERNOR_PER_POLICY` to `_mt_cpufreq_driver.flags` in `mtk_cpufreq_main.c:1384`.
  - Then set asymmetric cluster rate limits in `init.mt6768.rc`:
    - `policy0` (6× A55 efficiency): `up_rate_limit_us = 1000`, `down_rate_limit_us = 10000` (absorbs tiny background jitter without unnecessary spikes, holds smoothly through scrolling).
    - `policy6` (2× A75 performance): `up_rate_limit_us = 500`, `down_rate_limit_us = 20000` (fast ramp on UI/render bursts, prevents 1ms frequency drop oscillation).
- **Enable 16ms PELT half-life**: Switch `CONFIG_PELT_UTIL_HALFLIFE_32` -> `CONFIG_PELT_UTIL_HALFLIFE_16=y` in `yogurt_defconfig` for 2× faster load tracking aligned with 60Hz (`16.6 ms`) frame budgets (note: watch thermal/idle drain and rely on `schedtune`/PowerHAL defaults below to offset power).
- **Stop permanent boosting; use dynamic PowerHAL + `uclamp` cleanly**:
  - Remove `perfserv_ta_boost 15`, `perfserv_fg_boost 10`, and `gx_force_cpu_boost 1` from `sys.boot_completed=1` in `init.mt6768.rc` (let `powercontable.xml` defaults `0` hold when idle, and let `INTERACTION` / `LAUNCH` / `FIXED_PERFORMANCE` / `EXPENSIVE_RENDERING` in `powerscntbl.xml` boost transiently).
  - Keep `/dev/stune/top-app/schedtune.prefer_idle 1`, `schedtune.boost 1` (or `0-5` max) instead of `10`, and tune `sched_migration_cost_ns` (`250000`–`500000` ns) + `cpuset` separation (`background`: `0-3` or `0-2`, `system-background`: `0-5` or `0-3`, `foreground`/`top-app`: `0-7`, `restricted`: `0-3`).
- **Verify `powerscntbl.xml` `INTERACTION` touch-boost duration**: Line 9 currently specifies `1000000000` (`PERF_RES_POWERHAL_TOUCH_BOOST_DURATION`); verify MTK `libpowerhal` units (if ms vs ns — if ms, clamp to `80-250`; check `powercontable.xml` `INTERACTION` behavior on live touch).

#### 2. RAM, ZRAM & VM Efficiency (4 GB LPDDR4X)
- **Eliminate `zstd` level-3 compression CPU tax**:
  - **Best Smoothness + Battery**: Use **`lz4`** (`write /sys/block/zram0/comp_algorithm lz4` and delete the duplicate `zstd` override line in `init.mt6768.rc` & `init.ago.rc`). `lz4` is ~4–5× faster at compression and ~2× faster at decompression than zstd-3, avoiding A55/A75 core saturation during memory pressure.
  - **Best Hybrid Ratio + Low Overhead**: If you want zstd's ~30–40% higher capacity on 4 GB RAM without level-3 lag spikes, patch `#define ZSTD_DEF_LEVEL 1` in `crypto/zstd.c:26` (level 1 is dramatically faster than level 3) OR benchmark `lz4` vs `zstd` level 1 under heavy app switching.
- **VM & LMKD Synergy**:
  - Keep `page-cluster = 0` and `vma_ra_enabled = false` (ZRAM has zero seek latency; single-page fault avoids wasted decompression).
  - With `lz4`, set `vm.swappiness = 100` (or `120–140` if kernel allows >100; note 4.14 standard caps `swappiness` at `100` unless patched to `200`). Check `/proc/sys/vm/watermark_scale_factor`: test **`100`** vs `150` (`150` leaves 1.5% RAM margin for kswapd, `100` reduces premature kswapd wakeups while keeping headroom if `allocstall` stays low).
  - Keep `vfs_cache_pressure = 100` (balanced dentry/inode cache vs page cache), `dirty_background_ratio = 5`, `dirty_ratio = 15` (avoids 20% big dirty flushes blocking eMMC writes!), `dirty_writeback_centisecs = 300`, `stat_interval = 10`.
  - Clean up `init.ago.rc` (either remove unused `/dev/memcg/` writes since `CONFIG_MEMCG` is disabled, or align `init.ago.rc` with `init.mt6768.rc`).

#### 3. GPU & Frame Pacing (Mali-G52 MC2 + GED + FPSGO)
- **GED / Mali parameters**:
  - Keep `gpu_dvfs_enable = 1`, `ged_boost_enable = 1`, `ged_smart_boost = 1` (smart 3D fence boost), and `enable_gpu_boost = 1`, while keeping **`gx_force_cpu_boost = 0`** by default so PowerHAL/FPSGO (`EXPENSIVE_RENDERING` / `FIXED_PERFORMANCE`) controls CPU floor dynamically.
  - Ensure `SurfaceFlinger` / HWC `EXPENSIVE_RENDERING` triggers cleanly without pinning `gx_force_cpu_boost=1` 24/7.
- **Check Kernel `CONFIG_MTK_GPU_SWPM_SUPPORT` / PowerHAL paths**: Notice [powercontable.xml](file:///mnt/rombuild/device/micromax/yogurt/configs/power/powercontable.xml#L201-L246) writes to `/sys/kernel/debug/fpsgo/...` and `/d/ged/...`; recall `enforce_debugfs_restriction` on `user` builds blocks non-exempt domains from reading/writing `debugfs` unless explicitly handled or moved to `procfs`/`sysfs`. Verify `mtk_hal_power` access or move critical FPSGO/GED knobs to `/proc/` or `/sys/module/` if needed on `user` builds.

#### 4. Battery, Idle & Suspend
- **Post-boot `rcu_expedited` toggle**: Leave `write /sys/kernel/rcu_expedited 1` in `on late-init` for fast boot, and add `write /sys/kernel/rcu_expedited 0` in `on property:sys.boot_completed=1` to eliminate post-boot expedited RCU IPIs and boost idle/deep-sleep battery life.
- **Enable async suspend**: Remove `write /sys/power/pm_async 0` (`init.mt6768.rc:653`) or test `1` after validating MT6768 peripherals (check if any MTK driver fails async suspend before keeping `1`).
- **Keep `CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y`** (already enabled!) and verify `/sys/power/mem_sleep` remains `[deep]` (`s2idle [deep]`).
- **Network**: `fq` + `bbr` is already active and compiled in (`CONFIG_TCP_CONG_BBR=y`) — great for mobile bufferbloat & tail latency.

#### 5. Storage & Filesystem (eMMC + F2FS)
- Kernel `drivers/mmc/core/queue.c` uses MediaTek CMDQ single-queue (`deadline`, `cfq`, `noop`), NOT `blk-mq`. Keep `scheduler = deadline` (or test `cfq` low-latency if heavy background writes starve UI), `iostats = 0`, `rq_affinity = 2`, `nr_requests = 128`, `read_ahead_kb = 128` (or `256` max; avoid `2048` post-boot which causes read amplification on eMMC random I/O).
- F2FS `/data` already mounts with `noatime,lazytime,discard,noflush_merge,fsync_mode=nobarrier,checkpoint=fs,extent_cache,inline_xattr,inline_data,inline_dentry`. Keep `readahead_size_kb=128`.

---

### Tier 2 — Medium Complexity Backports & Log Cleanups

1. **Backport Multi-Gen LRU (`MGLRU` / `CONFIG_LRU_GEN`) to `4.14.141`**:
   - Replaces legacy 2-list active/inactive LRU scanning (`pgscan_direct = 12916` observed at 45s uptime!).
   - Reduces page reclaim CPU overhead and refaults by 15–50% on 4 GB devices, making `zram` + background app retention dramatically smoother.
2. **Fix `E/ashmem: readlink(/proc/self/fd/...)` (`system/core/libcutils/ashmem-dev.cpp`)**:
   - Switch `is_memfd_fd()` from `readlink("/proc/self/fd/...")` to `fcntl(fd, F_GET_SEALS) >= 0` (eliminates 43+ WebView/Chromium permission errors per session).
3. **Fix `E/SystemServiceRegistry: Manager wrapper not available: obscura`**:
   - Gate `Context.OBSCURA_SERVICE` lookup or adjust `service_contexts`/AppOps callers so unprivileged apps don't log `799+` errors on boot.
4. **Compiler & Linker Kernel Wins**:
   - Kernel currently builds with `clang r353983c` (Clang 9.0.3). Keeping LTO off on old 4.14 `r353983c` is safer; ensure `CONFIG_ARM64_LSE_ATOMICS` / `CONFIG_AS_LSE=y` and `-mtune=cortex-a75` (already set!) remain active, and disable unused kernel tracers/debug configs in `yogurt_defconfig` (`CONFIG_MTK_SCHED_TRACERS` if unused).

---

### Tier 3 — High Complexity (Optional Future Work)

1. **Cgroup v2 Freezer (`cgroup.freeze`) + Binder Freeze Notification Backport**:
   - Resolves `SensorService: Failed to addFrozenStateChangeCallback (-38)` and enables true zero-CPU background app freezing on Android 17 instead of v1 fallback. (Requires careful synchronization with `4.14` binder & scheduler locks; alternatively verify `suspend_sensor_event_delivery_on_frozen_pid` flag behavior if not backporting.)
2. **Evaluate `CONFIG_MEMCG` vs Non-MEMCG on 4 GB RAM**:
   - Enabling `CONFIG_MEMCG` unlocks per-cgroup `lmkd` memory accounting & `/dev/memcg/`, at a cost of ~15–35 MB kernel slab/page_cgroup metadata + minor allocation fastpath overhead. Only worth enabling alongside `MGLRU` if LMKD PSI mode isn't selective enough.
3. **`CONFIG_DMABUF_SYSFS_STATS` Backport**:
   - Eliminates the 13 `system_server` `/sys/kernel/dmabuf/buffers` errors and populates `dmabuf` totals in `dumpsys meminfo`, though ION -> dmabuf accounting in 4.14 MTK requires exporter hooks.

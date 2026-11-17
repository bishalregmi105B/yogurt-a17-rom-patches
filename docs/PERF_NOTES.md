# PERF_NOTES.md — performance engineering record, yogurt (E7746)

Hardware envelope (VERIFIED, recon/): Helio G85 (mt6768) + Mali-G52 MC2, 4 GB RAM,
60 Hz panel, eMMC. Priorities per Master Prompt §10: memory pressure > jank >
thermals > battery. Rule of the doc: **every deviation from stock is listed here with
its rationale and risk — nothing silent.** This file is v0.2 (pre-build); rows are
`UNTESTED` until the built ROM boots; verified rows get a VERIFIED stamp + measured
value in v1.0.

## A. Deliberate NON-changes (stock-proven, copied byte-identical)

| Domain | Decision | Why (evidence) | Risk |
|---|---|---|---|
| zram sizing | 55 % of RAM (stock value) | recon/community DF13 already proved the value on this exact vendor | low |
| MTK power HAL / PerfService / thermal | vendor configs untouched | §10: prefer the vendor's proven tuning over invented numbers | none (that is the point) |
| Charger/health behavior | health@2.1 vendor service, stock 18 W animation | stock chain retained | none |
| I/O scheduler | vendor default kept | no DIY wins provable offline | none |
| fstab mount flags | stock flags incl. FBE, metadata crypt, `nvdata/nvcfg/persist`, microSD `voldmanaged` path | Gate G4 diff at build | none |
| fstrim schedule | intact via stock (maintenance job) | A16 `fw/boot-time` writes ignored | none |

## B. Kernel (Phase 1 = prebuilt proven boot.img — no deviation at all)

Phase 1 kernel is byte-proven stock-derived (4.14.141-yogurt). Zero kernel deviation.
The eBPF gaps (BPF_JIT, NET_ACT_BPF) are accounted for in KNOWN_ISSUES §5.

Phase 2 (later, source build) will add exactly: BPF_JIT=n→y, NET_ACT_BPF, keep PSI,
lz4/zstd zram compressor — config diff lands here when it exists, each item with
kernel-source citation (android-4.14-stable cherry-picks) + regression risk.

## C. ART / boot-time knobs (build-time, in device tree)

| Knob | Value (planned) | Rationale | Risk |
|---|---|---|---|
| `WITH_DEXPREOPT` | on | first-boot trims + janitor RAM | build size discipline (out/ pruned) |
| compile filter | `speed-profile` | stock-like perceived launch speed | profile staleness → re-open at v1.0 |
| dalvik heap | `phone-xhdpi-4096-dalvik-heap.mk` (i.e. the 4 GB heap config family) | matches 4 GB RAM envelope | heap-shortage GC churn → watch lowmemkiller in collected logs |
| `ro.config.low_ram` | **not set** (explicit) | wrong signal for 4 GB smart-phone profile; hurts SystemUI features | none |
| lmkd | PSI monitoring on, `ro.lmk.*` conservative AOSP defaults | 4 GB needs sane kill curve | OOM harshness → tune only with the PSI traces from collection runs |

## D. Graphics / UI knobs

| Knob | Value (planned) | Rationale | Risk |
|---|---|---|---|
| Renderer | vendor-validated (Skia GL) | Mali-G52 MC2 on 4.14/vendor = keep | none |
| Vulkan | off (not forced) | vendor Vulkan driver unproven on dual-camera HWC 2.1 path | none |
| Blur/effects | background/window blur **off by default** | Mali-G52 MC2 budget; per §10 | cosmetic |
| Animation scales | stock defaults (1x) | respect §10 "no fake fluency" | none |
| Refresh rate | 60 Hz only | panel hardware constant | none |
| Doze/standby | AOSP defaults | standard battery path | none |

## E. Memory-pressure watchlist (electric fence at 4 GB)

Measured to-do list (fills at first boot with collection zip):
1. PSI full/avg10/avg60 sample at idle → vs. DF13 baseline extrapolation.
2. Janky-frame % in `dumpsys gfxinfo` for SystemUI + launcher after 10 min use.
3. Thermal state transitions during 15 min camera → charging.
4. `am_pss`/`lmkd` kill trace sanity — no system_server-kills spikes.
5. zram: `cat /sys/block/zram0/mm_stat` ratios under churn.

## F. Debloat ledger

Provable-unused removals only (§10). Currently planned: none beyond DerpFest product
narrowing — list here if/when the GApps volume forces trims (G4 rule: trim GApps
before touching partitions).

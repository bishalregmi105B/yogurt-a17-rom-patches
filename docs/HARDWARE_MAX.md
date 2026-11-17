# HARDWARE MAX — what this device's silicon actually maxes out at (yogurt)

Status: evidence-locked against the live device 2026-10-25 (recon/live_audit/hwmax.txt,
camdump_full.txt) · 2026-10-25. Companion to PERF_NOTES.md (system-side perf plan)
and CAMERA_RESEARCH.md (camera mechanisms). One principle: **utilize everything the
hardware documents; never advertise what the silicon doesn't provide.**

## Subsystem matrix — maximum capability & what our ROM does

| Subsystem | Hardware max (VERIFIED) | ROM action | Label |
|---|---|---|---|
| CPU little cluster | 6 × A55 @ **1.8 GHz** (policy0 scaling_max == cpuinfo_max) | nothing to unlock — already at silicon ceiling; keep fpsgo/thermal untouched | MAXED-OUT ALREADY |
| CPU big cluster | 2 × A75 @ **2.0 GHz** (policy6 scaling_max == cpuinfo_max) | same | MAXED-OUT ALREADY |
| GPU | Mali-G52 MC2; DVFS nodes NOT exposed by this kernel (/sys/kernel/ged / mali absent) | keep vendor driver/limits; no freq games possible from ROM side | VENDOR-DRIVEN |
| RAM | 4 GB total → 3,848,100 kB usable; heap 192m/512m standard 4 GB spec | zram ~55 %, PSI-lmkd, runlxmpolicy per PERF_NOTES | TUNED (release-verify) |
| Runtime/dexopt | dex2oat64 on, jit+profiles on, secondary dexopt on, thermal-cutoff 2, system-UI speed filter | byte-identical carry-through + speed-profile preopt | CARRIED BYTE-IDENTICAL |
| Thermal | thermal + thermalloadalgod running; thermal-cutoff=2 | keep vendors' thermal tables (no fake limit removal — that causes shutdowns) | KEPT INTACT |
| Storage/IO | eMMC (sched listing failed this pass — re-dump via `ls /sys/block` name loop post-flash if logs require) | I/O preopt, zygote cache, no exotic sched swaps | CARRIED + VERIFY |
| Audio | AW881xx smart-amp firmware + BES loudness=1 | keep | CARRIED |
| Display | panel-refresh as vendor packages it | keep; no panel refresh hacks (LCD) | KEPT |
| Camera — streams | 4K30 on main+front (YUV/JPEG/RAW/IMPL streams) — everything HAL publishes exposed to all apps after unlock | it is all kept and enabled | MAX (packagelist="*") |
| Camera — fps | 1080p & 720p high-speed **30..120 fps** (60 is a legit subset); standard AE [5..30] | 4K30 + HS 60/120 surfaced via OpenCamera/Aperture; 4K60/OIS/>120 never advertised (AE ceiling 30; OIS byte=0 all 6 devices) | MAX (in-truth) |
| Camera — processing | MTK's own burst stacks present as HAL feature sections: **abffeature (AEB fusion ≈ HDR+), mfnrfeature (multi-frame NR ≈ night mode), eisfeature, smvrfeature (slow-mo), multicamfeature, nrfeature, hdrfeature, vsdoffeature, cshotfeature** | verify reachability by non-whitelisted clients post-unlock; no blind props | VERIFY POST-FLASH |
| Camera — 48 MP | remosaicenable gate on logical composite | any app after packagelist unlock | UNLOCK (rc) |
| Fingerprint side-effect | crash-loop every ~5 s burns CPU/battery | sepolicy fix (staged) | FIX STAGED |
| Client-package FW patch | HAL has NO package-name vendor tag (21 sections audited) | **SKIPPED** — data a blob can't read | SKIP WITH PROOF |

## The one-line math
- Chip: G85 = fully maxed at stock freqs → "performance" comes from **latency & memory
  management** (zram/PSI/lmkd/preopt), **removing crash-loops** (fingerprint fix),
  and **unlocks** (camera aux packagelist) — not from exotic boost hacks that
  MTK thermal/sched policy would hot-clamp anyway.
- Camera: all published streams × all apps; 48 MP composite; HS 60/120 — and the
  honest "never-fake" list pinned for 4K60 / OIS / >120.

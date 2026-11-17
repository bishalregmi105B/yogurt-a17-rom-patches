# FEASIBILITY — Gate G0 (research/FEASIBILITY.md)

Verdict scope: produce a **flashable DerpFest for yogurt (E7746)**. Updated 2026-10-25
after matrix scoring (see FINDINGS §3) and on-device recon.

## Chosen tier and branch (LOCKED)

**T2 — DerpFest 16.2 (Android 16 QPR2, lineage-23.2 / android-16.0.0_r4), full device
tree from yogurt-devs bases, prebuilt 4.14 kernel first (Phase 1), source kernel after.**

Rationale (in evidence order):
1. VINTF: the A16 (16.2) tree ships `compatibility_matrix.5.xml` as an **empty**
   placeholder — the deliberate Android-16 escape hatch for Android 11-era/R-class
   vendors — which is exactly our vendor class (R-class, target-level 4 today).
   Setting `target-level="5"` on our re-declared vendor manifest gives a clean static
   VINTF pass with all existing stock HALs intact.
2. Kernel: level-6/7 matrices still carry `kernel_config_s_4.14`/`t_4.14` config
   requirement sets; level 5 carries none; so a 4.14 kernel is admissible. A17 (df17)
   ships NO level-5 lane and demands level 6.android17+ (full S-compliance incl.
   IRadio 1.6) → **17 must come after 16.2**, if at all, on a proven base.
3. Community precedent: this exact device boots DerpFest 13 with the same blob set;
   the deltas to 16.2 are: framework version, matrix level, product flags, recovery.
4. mt6768-S (S-vendor 4.19) path is NOT copyable (Micromax never shipped an S vendor).

Fallback: T3 — build a DerpFest-flavored Treble GSI FROM the same 16.2 tree with
TrebleDroid/phh patches on the untouched stock vendor/boot. Only if T2's runtime
HAL bridging (audio 6.0 / radio 1.2-1.4 / fingerprint HIDL) proves unbridgeable.

## Partition budget (G4, from BoardConfig + on-device facts)

- super = 9,126,805,504 B total; group `micromax_dynamic_partitions`
  (system+vendor+product only). BoardConfig sets reserved sizes per image; Android 16
  system (~2.0–2.4 GB product-inclusive) + recovery-era DerpFest GApps fits per
  BoardConfig values seen on 13 (community proved fit with VNDK 33 vendor ~1.2 GB).
- ext4 for system/vendor/product; recovery/boot/dtbo/vbmeta — actual headers copied
  from stock parameter set (base 0x40078000, page 2048, cmdline unchanged).

## Risk table (from highest to lowest)

| # | Risk | Evidence | Mitigation |
|---|---|---|---|
| R1 | **Modem/RIL/IMS**: vendor has radio@1.2/1.4 + radio.config@1.1 + mtkradioex@1.9; A16 telephony expects 1.5+/AIDL. Level-5 declaration leaves this runtime-visible. | matrix requires radio 1.5-6 at level 6 — our vendor misses | PHH/PXmediatek-ims style radio shim ports into our vendor tree (studied from mt6768-S/merlin trees); device prop-side `MTK` IMS chain already validated at A13 by community forks |
| R2 | **Audio 6.0 HIDL** vs A16 libaudiohal (may have dropped <7.0 HIDL) | matrix.8+/2024x removed HIDL<7.0; 6.0 accepted at level 6/7 | verify `AudioHalVersionInfo` support set in synced tree; add HIDL 6.0 support back as framework-side shim if removed |
| R3 | fingerprint: HIDL 2.1 served; confirm framework fingerprint bridge survives A16 | community shipped aidl light/vibrator but FP stayed HIDL | inspect synced frameworks/base biometrics; port fingerprint quirk set from phh; testbed static first |
| R4 | keymaster@4.0 + keystore2/km_compat at A16 | matrix accepts km 4.1 at level ≤7 | OK at level-5 declaration; verify keystore2 shim in tree; enrollment depends on gatekeeper/tee beanpod intactness |
| R5 | SELinux: community sepolicy = ArrowOS mt6768 fork; TARGET_USING_LEGACY_SELINUX | villages 13 worked but A16 userspace policy changed (genfs, ioctls) | reuse arrow-14.0 sepolicy + neverallow walk; no permissive |
| R6 | eBPF gaps (BPF_JIT, NET_ACT_BPF missing) → tethering netd expectations | kernel_config.txt | Phase 1: extract netd requirements; Phase 2 kernel rebuild adds options |
| R7 | disk throughput (HDD ~340 GB ext4) + 3 GB RAM | host facts | -j3, ccache 15 GB, watchdog, LEAN sync+single product; out/ pruned aggressively; contentcache |
| R8 | OTA zip packing: A-only non-dynamic-slot device with recovery partition | BoardConfig | build lineage-style OTA with recovery; sideload via our recovery; disabled-verity vbmeta shipped |

## Gates state

- **G0** (this file): DONE at 2026-10-25.
- **G1** kernel/eBPF: Phase 1 = prebuilt boot from known-good yogurt boot.img; Phase
  2 = source with BPF backports + pure Clang/LLD. Pending (needs boot.img from B2,
  and a synced build env).
- **G2** VINTF/HAL: strategy locked (target-level=5 + community AIDL for light /
  vibrator / bt.audio / NN which are ALREADY served AIDL by the currently-working
  build, keep the rest stock-HIDL). Runtime verification checkvintf at build.
- **G3** SELinux: sepolicy_vndr (ArrowOS 14.0) + TARGET_USING_LEGACY_SELINUX = Enforcing.
- **G4** images: ext4 everywhere; sizes from BoardConfig + lpmake/lpdump vs stock.
- **G5** static launch checks (§13): run at build completion.

## Feasibility call

**GO for T2 (16.2)** with R1/R2/R3 as the explicit watchpoints, and a locked plan B
(T3 GSI path) if any of them proves hard-blocked statically before the first build.

# KNOWN_ISSUES.md — DerpFest 16.2 for yogurt (Micromax IN Note 1 / E7746)

Status vocabulary (honest labeling per Master Prompt §15):

- `FIX PLANNED` — engineering path decided in research/, not yet proven anywhere.
- `AUTHORED · UNTESTED` — config/code path is present or planned in our tree; needs the
  synced tree inspection and/or an on-device run (post_flash_collect_logs.sh) to prove.
- `WORKS-BY-DESIGN · UNTESTED` — we keep the stock/community-proven value unchanged so
  the issue should not exist; still requires on-device proof.
- `ACCEPTED` — ships as-is, documented for the user.

Doc version **v0.2 (pre-build, 2026-10-25)**. Rewritten to v1.0 right after the first
successful build + static gates; the per-item final VERIFIED/UNTESTED table lives in
`COMPAT_REPORT.md`.

---

## 1. Rear fingerprint — **ROOT CAUSE FOUND on live device (2026-10-25)**

- **Root cause (not hardware):`venndbinder map` SELinux denial in the
  `hal_fingerprint_default` domain kills the vendor HAL at HwBinder init —
  exact abort message captured from a real tombstone on the running ROM:**
  `Binder driver '/dev/vndbinder' could not be opened. Terminating: Using
  /dev/vndbinder failed: unable to mmap transaction memory.` (evidence:
  recon/live_audit/crash_buffer.txt + FINDINGS §10a).
- The full denial set to fix in OUR tree (all sepolicy-side, no vendor edits):
  1. `hal_fingerprint_default { map open rw } /dev/vndbinder`
  2. `hal_fingerprint_default { open read write create } /data/vendor/focaltech/*`
     (or a typed `focaltech_data_file` + filetrans)
  3. `hal_fingerprint_default netlink_kobject_uevent_socket create/read/write/bind`
- Status of other checklist lines from §9: AT THE FIX PLAN stage:
  - framework Fingerprint21 HIDL 2.1 bridge: VERIFIED ALIVE on-device (A13)
    retries properly — keep untouched at 16.2.
  - `ro.vendor.*` stay byte-identical: WORKS-BY-DESIGN · UNTESTED.
  - TEE/beanpod chain: process already running on live device (`dumpsys
    biometric` sensors healthy) — carry through in 16.2: UNTESTED.
- Acceptance criterion for the fix (P7 static + first boot): `getprop
  sys.init.updatable_crashing` empty; `lshal | grep fingerprint` shows
  biometrics@2.1 + focaltech@1.0; `logcat -d | grep Fingerprint21` = "daemon
  connected" not "HAL not available".

## 2. VoLTE / IMS (risk R1 — research/FEASIBILITY.md)

- Ground truth: `android.hardware.radio@1.2`, `radio.config@1.1`,
  `vendor.mediatek.hardware.mtkradioex@1.9::IMtkRadioEx/imsSlot1|2` (vendor manifest).
- A16 telephony framework targets IRadio 1.5+/AIDL; the ≤1.4 HIDL bridge must be
  confirmed in the synced tree — **AUTHORED · UNTESTED**.
- Evidence the IMS chain itself still runs on this device under a custom ROM:
  `init.svc.volte_imsm_93: running` observed on-device during recon
  (recon/getprop.txt) — but that was Android 13-era; **A16 parity UNTESTED**.
- Fallback semantics if 16.2 RIL shim lags: SMS + mobile data expected to work,
  VoLTE may drop to emergency+CSFB. Reported honestly on ship.

## 3. Audio: vendor HIDL 6.0 vs A16 `libaudiohal` (risk R2)

- Vendor serves `android.hardware.audio/-audio.effect` **6.0** (device manifest) and A16
  may accept anything < 7.0 depending on `AudioHalVersionInfo`; level-5 matrix has no
  say here (it is empty), so this is a **framework runtime** question.
- Plan: confirm 6.0 handling in the synced tree; if absent, restore a framework-side
  HIDL 6.0 shim (preferred over touching vendor blobs).
- BT audio: the vendor already serves AIDL (`bluetooth_audio` fragment) — expected OK.
- All of it: **AUTHORED / FIX PLANNED · UNTESTED**.

## 4. Keystore2 + keymaster@4.0 (beanpod), gatekeeper@1.0 (risk R4)

- Static: matrix level 5/6/7 accepts keymaster 4.0-1 and gatekeeper 1.0 → VINTF clean.
- Runtime: `keystore2` must use the HIDL `keymaster@4.0` compat path (km_compat) —
  **AUTHORED · UNTESTED**. Everything on the phone leans on it (screen-lock creds, FBE,
  fingerprint enrollment), so first-boot `dumpsys keystore` is in
  `post_flash_collect_logs.sh`.

## 5. Tethering / netd eBPF with the stock 4.14.141 kernel (risk R6)

- recon/kernel_config.txt shows BPF_JIT and NET_ACT_BPF missing (BPF core, cgroup BPF,
  xt_bpf, cls_bpf, sch_ingress, PSI present).
- Phase 1 (prebuilt kernel from the proven DerpFest 13 boot.img): hotspot/netd traffic
  may fall back or fail — **ACCEPTED for Phase 1**, explicitly re-tested; the collector
  grabs `dumpsys wifi` + logcat netd lines.
- Phase 2 (source kernel from SakthivelNadar/yogurt, clang-only): BPF_JIT +
  NET_ACT_BPF backported → **FIX PLANNED**.

## 6. Widevine level (L1 vs L3) — **UNTESTED by construction**

- `manifest_android.hardware.drm@1.4-service.widevine.xml` fragment present on the
  vendor; whether L1 secrets survive a re-built system is only provable on-device
  (`dumpsys media.drm` — inside the collector).

## 7. Play Integrity / SafetyNet (Master Prompt §9B)

- **STRONG** integrity requires a hardware-attested keybox — impossible for us, ever;
  reported honestly in the final report.
- **BASIC/DEVICE** depend on unlocked bootloader state + GMS + DerpFest's built-in
  prop-spoofing flow. No custom spoof hacks are added; the check runs post-flash and
  the result lands in the final report.

## 8. Recovery / OTA flow caveats (must-read before flashing)

- Bootloader unlocked already on this device (user's own action).
- `vbmeta` flash with `--disable-verity --disable-verification` required (the ONLY
  allowed relaxation) — see `INSTALL.md`.
- **Format /data is required** for the DF13 → DF16.2 jump (FBE key + keystore
  generation change). `RESTORE_STOCK.md` covers getting back.
- No TWRP-era zips: sideload through the recovery built from this tree.

## 9. Bring-up aids ledger (must be EMPTY for the final build)

- `ALLOW_MISSING_DEPENDENCIES`, `BUILD_BROKEN_*` flags used per build are tracked in
  `STATE.md` (P6/P7) and transcribed here; the final build target has zero unless an
  item has a written justification tied to a KNOWN_ISSUES entry.

## 10. Things intentionally NOT changed (WORKS-BY-DESIGN)

- Kernel first (Phase 1) = proven prebuilt from the DF13 boot.img; only Phase 2 rebuilds.
- Vendor power/thermal/PerfService/charging configs kept as stock (§10 of the spec).
- zram 55 %, fstab flags (`nvdata/nvcfg/persist`, FBE), microSD `voldmanaged` semantics
  copied from stock — deviations go to `PERF_NOTES.md`, nothing silent.

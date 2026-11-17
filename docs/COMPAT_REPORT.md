# COMPAT_REPORT.md — HAL-by-HAL compatibility call, yogurt (E7746)

Judging basis (all static evidence, dated 2026-10-25):

- Vendor interface truth: `recon/vendor_manifest.xml` + the 10
  `recon/vintf_full/vendoretc_vintf/manifest/*.xml` fragments (copied from the live
  device `/vendor/etc/vintf/manifest*`) + `recon/odm_manifest.xml`.
- Target acceptance: research/matrices/ (lineage-23.2 `compatibility_matrix.5.xml` is
  **empty** ⇒ at `target-level="5"` no HAL is framework-required → static pass is a
  re-declaration exercise; real ground truth wins at runtime).
- Status legend: **OK** = accepted as-is → keep blob+HAL; **SHIM** = needs a
  framework-side bridge/shim (authored in-tree, not in vendor); **MISSING** = HAL the
  phone needs but vendor lacks (none so far at level 5).

Every row carries `runtime: UNTESTED` until `post_flash_collect_logs.sh` output comes
back from a flashed device. Nothing here is a hardware claim.

## Device-oxygen HALs (from device manifest)

| HAL | Stock version | Call | Evidence / notes |
|---|---|---|---|
| graphics.composer | 2.1 (HWC 2.1 @0x`dq_deep`? real service in manifest) | OK | level-5 empty matrix; A16 keeps HWC 2.1 compat path |
| graphics.allocator / mapper | 2.0 / 2.1 | OK | standard gralloc compat |
| memtrack | 1.0 | OK | |
| power | 1.3 HIDL | OK → verify | A16 power is AIDL; HIDL 1.3 bridge must exist in synced hw power tree — *this is a P5 check* |
| sensors | 2.0 | OK | nvcfg calibration data follows vendor |
| fingerprint (biometrics) | 2.1 HIDL + focaltech@1.0 | SHIM | HIDL→AIDL bridge + km chain; see KNOWN_ISSUES §1; feature XML `android.hardware.fingerprint.xml` stays |
| light / vibrator | AIDL (yogurt fragments) | OK | community AIDL already proven on the DF13 install |
| bluetooth | 1.0 HCI | OK | |
| bluetooth audio | AIDL (bluetooth_audio fragment) | OK | |
| usb | 1.1 | OK | configfs GSI semantics differ A10→A16 — runtime watch |
| wifi | 1.3 + hostapd 1.1 + supplicant 1.2 | OK | connsys firmware identical |
| gnss | 1.1 **and** 2.0 | OK | |
| camera.provider | 2.4 | OK → verify | A16 legacy provider 2.4 path must stay present in synced camera framework |
| camera MTK extras | `camera.bgservice` 1.1, vendor tags | OK | retained blobs |
| secure_element | declared (version per fragment) | OK | needed only if eSIM/SE flows used |
| drm | clearkey $drm 1.x + widevine 1.4 fragments | OK | L1/L3 = UNTESTED (KNOWN_ISSUES §6) |
| cas | 1.2 | OK | |
| neuralnetworks | 1.3 MTK-GPU | OK | deprecated-but-bridged on A16 |
| audio / audio.effect | **6.0** HIDL | SHIM | R2: confirm A16 `libaudiohal` still loads pre-7.0 HIDL; else framework shim |
| media.omx | 1.0 | OK | legacy codec2-conversion path stays |
| health | 2.1 | OK | charger/18W thermals follow vendor config |
| keymaster | 4.0 (beanpod) | SHIM | keystore2/km_compat; gatekeeper 1.0 likewise |
| gatekeeper | 1.0 | SHIM | same keystore2 bridge |
| radio / radio.config | 1.2 / 1.1 | SHIM | ≤1.4 bridge in A16 telephony (P5 proof) |
| mtkradioex | 1.9 (imsSlot1/2) | SHIM | IMS chain; VoLTE best-effort (KNOWN_ISSUES §2) |
| configstore | 1.1 | OK | deprecated, still bound |
| renderscript | 1.0 | OK | unused by A16 framework; harmless |
| MTK vendor-private (atci 1.0, dfps, mtkperf, …) | as declared | OK | retained verbatim in vendor tree |

## Aggregate call (static, pre-build)

- **MISSING count: 0** at `target-level="5"`.
- **SHIM count: 7** (fingerprint, audio(-effect), keymaster, gatekeeper, radio,
  mtkradioex(-ims), + conditional power/camera-framework checks) — all of type
  "framework keeps speaking vendor's older HAL dialect", i.e. exactly the class of
  fix the spec prefers (bridge on our side, never edit vendor blobs).
- Static VINTF assembly plan: re-declare the stock vendor manifest unchanged with
  `target-level="5"`, `check_vintf`/`assemble_vintf` in build, and keep the AIDL
  services (light/vibrator/bt.audio/NN) the community already added for the DF13 ROM.

_This file is v0.2 (pre-build). The final v1.0 table adds per-row VERIFIED/UNTESTED
from the collected post-flash evidence._

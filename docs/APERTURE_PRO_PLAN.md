# APERTURE PRO — system-camera extension plan (yogurt)

Status: AUTHORED SPEC (real control keys, verified on the live HAL) · implement in
tree post-sync as §8 of P5_RUNBOOK; ships inside the DerpFest build, no prebuilt APK
risk. The system camera app in this tree is **Aperture** (org.lineageos.aperture,
`.repo/manifests/snippets/lineage.xml`) — we build it from source, so edits are
first-class ROM work.

## What the HAL already publishes (VERIFIED, camdump tag dictionary)

| control (vendor section) | key | values on this device | meaning |
|---|---|---|---|
| `com.mediatek.mfnrfeature.availablemfbmodes` | 0x80040002 | **[0 1 2 255]** | multi-frame burst pipeline: OFF / ON / QUALITY / AUTO — the Mtk-native "HDR+/Deep-Fusion analog" (ABF/MFnR) |
| `com.mediatek.mfnrfeature.availableaismodes` | 0x80040005 | [0 1] | **AIS = anti-shake on stills** (the "stable photo" stack) |
| `com.mediatek.hdrfeature.availableHdrModesPhoto` | 0x80030004 | [0 1] | photo HDR toggle (`hdrMode` 0x80030000 / `SessionParamhdrMode` 0x80030001) |
| `com.mediatek.nrfeature.available3dnrmodes` | 0x80010001 | [0 1] | 3D NR (video denoise) |
| `com.mediatek.eisfeature.*` | eismode 0x80070000, previeweis | EIS controls for video | stable 4K30/1080p recording |
| `com.mediatek.control.capture` | remosaicenable 0x800b0006 | 48 MP quad-bayer full-res still | unlock + app toggle |
| HS video tables | CONSTRAINED_HIGH_SPEED_VIDEO | 1080p & 720p @ 30..120 | slow-mo / high-speed record incl. 60 fps subset |
| FULL level + RAW + BURST + MANUAL | static caps | — | pro photo pipeline prerequisites |

## What Aperture gets (each = separate commit, feature-flagged, post-first-boot cycle)

1. **Pro mode** — manual ISO/exposure/focus/WB driven by Camera2 manual keys
   (halady FULL+MANUAL_SENSOR verified). Low risk, standard AOSP patterns.
2. **RAW (DNG) capture toggle** — RAW10 verified; app uses `DngCreator` on
   RAW stream + JPEG thumbnail passthrough. Low risk.
3. **Slow-motion / high-speed** — explicit ConstrainedHighSpeed session on
   `availableHighSpeedVideoConfigurations` (1080p 60 & 120) — needs the HPV
   capture path (fps ranges [60,60]/[120,120]) + recorder config. Medium
   complexity, device-verified acceptance battery in §7.
4. **"Turbo" quality toggle (default AUTO→mute user control)** — maps a user
   toggle to:
   - `mfbmode` (query `availablemfbmodes` at runtime; write accordingly), and
   - `hdrMode`/`SessionParamhdrMode` for photo HDR,
   - `aismode`=1 for stills when shutter < threshold.
   All writes go through session parameters / per-request vendor keys — this is
   the closest legitimate "iOS-processing-in-app" surface on this HAL, and it is
   REAL pipeline work by the vendor ISP (not an app-side filter).
5. **48 MP toggle** — find remosaic tag descriptor dynamically
   (`VendorTagDescriptor`, section `com.mediatek.control.capture`,
   name `remosaicenable`) and set it for still captures the stock 48 MP path
   uses; fall back gracefully if descriptor absent.
6. **EIS parity** — keep the vendor defaults; do NOT override `eismode` unless
   the user toggles stabilization explicitly.

## Acceptance battery (post-flash, logs attached)
- Pro mode: ISO/shutter/focus settable, values honored in EXIF.
- RAW: DNG opens with detail matching JPEG scene.
- Slow-mo: 1080p120 file @120 fps by metadata; 1080p60 mid-mode stable.
- MFB/HDR/AIS: enabling each changes measured frame count / sharpness; log the
  HAL's `mfbresult` results back as on-screen "processing" indicator (iOS-like).
- 48 MP: third-party OpenCamera SimpleShot + our toggle → full-res still.
- All toggles OFF = behavior identical to upstream Aperture (regression guard).

## What is NOT promised (honesty pins)
- No Google HDR+ / TrueLens binary lifelines; the "smart" layer = MTK's MFB/HDR/
  AIS vendor pipeline (already silicon-quality, and the best measurable path
  on this chip) + pro/RAW/HS app work.
- No 4K60 / OIS / >120 fps (physics), no GPU freq hacks (nodes absent).

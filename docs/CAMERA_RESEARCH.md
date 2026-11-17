# CAMERA RESEARCH — mechanism study & portability verdicts (yogurt / Micromax IN Note 1)

Status: COMPLETE (2 web research passes + live-device audit) · 2026-10-25
Ground truth refs: `recon/live_audit/fp_props.txt` (full getprop), `camdump_full.txt`,
`cam_parse.json`; first-pass sources in FINDINGS.md; device is fully unmodifiable
vendor blobs (mtkcam HAL 3.5) — every "HAL modification" below is runtime-prop /
framework-tag level by necessity and by spec rule (no vendor byte edits).

---

## 0. Live-device facts that anchor every verdict (VERIFIED)

| fact | value | implication |
|---|---|---|
| `vendor.camera.aux.packagelist` | `com.android.camera,com.google.camera,net.sourceforge.opencamera,org.lineageos.aperture` | **Per-app gate exists**: only whitelisted clients open the non-public device ids (HAL 2 depth sensor, HAL 5 logical multi = the 48 MP remosaic composite). This is the single biggest "apps outside system can't use high quality" lever. |
| `ro.vendor.mtk_slow_motion_support` | `1` | high-speed mode ALREADY unlocked for the stock pipeline (1080p≤120 tables present in dump) |
| `ro.vendor.mtk_zsdhdr_support` | `1` | ZSD-HDR vendor processing ALREADY on |
| main camera | FULL level, RAW10, BURST, MANUAL_SENSOR/MANUAL_POST, `edge/noise OFF-FAST-HIGH_QUALITY` | third-party apps may build burst/RAW pipelines **today** |
| AE ceiling | `[5..30]`, no 4K high-speed bucket; HS table = 1080p 30..120 (+720p) | 4K30 real, 4K60 physically absent |
| remosaic gate | `com.mediatek.control.capture` vendor tag `0x800b0006 remosaicenable` on the logical device | 48 MP stills gate by client identity — same family as OnePlus/Nothing per-client locks |

## 1. Mechanism taxonomy — what each source system does, and what moves to yogurt

### 1A. Property-driven gates (in-tree, ROM-side) — **PRIMARY DELIVERABLE**
Sources: Redmi-MT6768 `vendor.prop` practice (first pass), this device's getprop.
- `vendor.camera.aux.packagelist` — lives in vendor/build.prop; the HAL/provider
  reads it per client package. **Cannot edit vendor blob**, BUT init executes our
  device rc before any service starts, and a later `setprop` overrides the
  value it loaded from build.prop. Planned line (P5 §6 "RC-AUX-LIST"):
  `on early-init: setprop vendor.camera.aux.packagelist "*"`
  → every app becomes a permitted client; the 48 MP logical composite + all
  quality streams reach non-system apps without touching vendor.
  Fallback if the HAL parser rejects `*`: explicit app list appended to stock's 4.
  Companion: one neverallow-clean sepolicy allow for init to set that prop
  (property_contexts + `allow init <type>:property_service set;`).
- `ro.vendor.mtk_slow_motion_support=1`, `ro.vendor.mtk_zsdhdr_support=1` — already
  present on the live ROM; shipping byte-identical (no work, no risk).
- `persist.vendor.camera3.pipeline.bufnum.*` (Redmi tuning) — **SKIPPED by
  verdict**: values are tuned for Xiaomi's HAL build, not our vendor's; memory/
  latency regressions possible; only revisit with post-flash starvation logs.
- fpsgo / thermal / PQ props — untouched (vendor perf domain, already active).

### 1B. Framework vendortag (libcameraservice change) — **SECOND DELIVERABLE**
Source: BlissROMs review 19868 "libcameraservice: set vendor tag with client
package name" — *OEMs like OnePlus and Nothing detect camera package name to
unlock features like 48mp*. The vendor HAL gets told WHICH app is asking, and its
own policy (remosaic 48 MP, HDR modes) unlocks per client.
- Our HAL uses the same family of gates (aux packagelist, remosaicenable client
  gating). Port to A16 tree = frameworks/av change in the configure path.
- Label APPORT · UNTESTED (compile-level agreement only; behavior proved after
  first flash). This also future-proofs all three stock whitelisted paths.

### 1C. App-level processing stacks (camera apps) — NOT PORTABLE AS ROM
- **Google Pixel HDR+**: constant-exposure burst of Bayer RAW frames →
  FFT alignment + hybrid 2D/3D Wiener merge → exposure-fusion tone mapping;
  per-frame control via Camera2; runs on AP (Halide) or Pixel IPU.
  Sources: Hasinoff et al. 2016 (hdrplus.pdf), Google Research blogs
  (HDR+ 2014, HDR+ with Bracketing 2021, IPU 2017).
  - prerequisites the ROM must not break: RAW output, per-frame control,
    BURST — all VERIFIED present on yogurt. ✔
  - the pipeline itself is Google's proprietary app+libs; **cannot ship**.
  - GCam ports on Helio G-series: historically crash-on-open (celsoazevedo FAQ:
    "GCam ... doesn't work on most ... Mediatek SoCs"). No ROM-side promise; user
    experiment allowed post-flash, expectations low.
- **Nothing TrueLens Engine**: Nothing's in-app cross-sensor AI stack
  (multi-frame Bayer processing, ~22 algorithms), compiled into their camera
  app on their per-client harness. Not redistributable, not a system service.
- **Apple / "iOS-level"**: hardware ISP silicon (AVS/Photonic Engine) baked into
  each Apple SoC; ProRAW = RAW-domain multi-frame merge inside their ISP.
  Nothing of the silicon moves to mt6768 (Helio G85 ISP = MTK's own pipeline,
  already running its HIGH_QUALITY edge/denoise modes — we keep them ON and
  untouched).

### 1D. What "HAL efficiency" honestly means below the app level here
- Keep the vendor pipeline complete: every stock mode (ZSD-HDR, high-quality
  edge/noise, PQ/HDR video paths, remosaic 48 MP) shipped byte-identical. Any
  ROM that "optimizes" by disabling vendor stages LOSES quality on this HAL.
- Don't add props tuned for other vendors' HALs (bufnum skip verdict above).
- Efficiency surface we DO control: fpsgo stays enabled; zram/PSI/perf tuning
  per PERF_NOTES gives the camera processes headroom; the fingerprint sepolicy
  fix removes a crash-loop that burns CPU every 5 s (real battery/perf win).

## 2. Deliverable table — user's asks → honest outcome

| ask | delivery | label |
|---|---|---|
| "allow all high-quality streams to all camera apps outside system, don't lock to system" | `vendor.camera.aux.packagelist="*"` via device init rc (+ one sepolicy allow) | AUTHORED-CODE · UNTESTED (P5 §6) |
| same, deeper (per-app 48 MP/HDR gates inside HAL) | BlissROMs-19864-style libcameraservice vendortag port to A16 | APPORT · UNTESTED |
| "iOS processing / TrueLens / Pixel HDR+" | prerequisites preserved & exposed (RAW/BURST/MANUAL/FULL on all public cams); vendor HIGH_QUALITY modes kept; no proprietary pipeline can ship | PARTIAL — hardware-bound, honestly labeled |
| "max fps/resolution/change full power" | everything the sensor exposes is kept and advertised: 4K30 (YUV/JPEG/RAW/IMPL streams verified), front 16 MP, 5 MP + 2×2 MP, RAW everywhere, 1080p≤120 high-speed already unlocked (`slow_motion=1`) | VERIFIED ALREADY-MAX |
| "4K60" | NOT IMPLEMENTED — AE table caps at 30, no 4K HS bucket; faking it = broken output | IMPOSSIBLE (hardware) |
| "48 MP for every app" | aux.packagelist unlock exposes HAL 5 logical composite to all clients; remosaicenable stays vendor-controlled afterwards | AUTHORED-CODE · UNTESTED |
| "efficiency" | no bufnum/pipeline experiments (wrong-HAL risk); vendor modes untouched; perf-side wins via PERF_NOTES + fingerprint fix | VERIFIED-SAFE CHOICE |
| "JPEG 100 for all apps" | DROPPED — JPEG encode quality is inside the vendor blob; app-set JPEG quality passes through | NOT PORTABLE |

## 3. Post-flash acceptance (goes into post_flash battery, P5 §6)
1. `dumpsys media.camera` public device count ≥ 5 (was 4) → packagelist unlock OK.
2. `getprop vendor.camera.aux.packagelist` == our rc value.
3. remosaicenable still present in static characteristics (nothing stripped).
4. 4 in-tree camera apps + 1 third-party (OpenCamera) can open the logical
   camera and emit a 48 MP still (user-verifiable visually: zoomable detail).
5. Any denials/`avc` for init setting the prop or clients opening dev 5 →
   widen ONE allow at a time, log the exact rule.

## 4. Source list
- BlissROMs review 19868 (client-package vendortag) — review.blissroms.org
- Hasinoff, Sharlet, Geiss, Adams, Barron, Kainz, Chen, Levoy:
  "Burst photography for high dynamic range and low-light imaging on mobile
  cameras" (SIGGRAPH Asia 2016) — hdrplusdata.org/hdrplus.pdf
- Google Research blogs: HDR+ announcement (2014); Pixel Visual Core (2017);
  HDR+ Burst Dataset (2018); HDR+ with Bracketing (2021); Mobile Computational
  Photography tour (ar5iv 2102.09000)
- GCam mod handbook + FAQ (celsoazevedo.com) — MTK compatibility reality,
  HDR modes, lib mechanics
- Nothing TrueLens public materials (product pages/interviews; app-level AI stack)
- Live device: recon/live_audit/* (this document's §0 table)

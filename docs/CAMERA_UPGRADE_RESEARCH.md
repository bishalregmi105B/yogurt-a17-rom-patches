# Camera research: HAL, kernel, "camera engines", best achievable quality (IN Note 1 / MT6768)

Tags: **[V]** verified on the phone or in our tree, **[R]** web research summary (lead, test before trusting), **[P]** earlier project notes (`CAMERA_RESEARCH.md`, `APERTURE_PRO_PLAN.md`, `FINDINGS.md`).

## 1. Hardware and software stack [V]
- Cameras: back 48 MP quad-Bayer main (f/1.7, outputs 4000x3000 binned 12 MP; 48 MP only via vendor `remosaicenable` control), front 16 MP (f/2.0), 5 MP, two 2 MP depth/macro. FULL hardware level, RAW10, BURST, MANUAL_SENSOR/POST.
- HAL: MediaTek mtkcam, camera provider 2.4/2.5 (HIDL), HAL device v3.5, `camerahalserver` running. Closed vendor blobs.
- Vendor image-quality blocks present as libraries: `libcamalgo.3dnr`, `.abf`, `.eis`, `.asd`, `.fdft`, `.fsc`, `libcam.vhdr`, `libcam.hal3a.*` (auto exposure/focus/white balance + NVRAM tuning + DNG), `libbokeh_impl` + `libBSTDualCamBokeh`, ArcSoft beauty / scene detection / selfie.
- Live gates already open: `vendor.camera.aux.packagelist=*` (all apps may use the full camera set), slow-motion support on, ZSD-HDR on.
- Vendor controls the HAL publishes: MFNR/MFB modes [0 1 2 255], AIS (anti-shake stills) [0 1], photo HDR [0 1], 3DNR [0 1], EIS, remosaic (48 MP). Aperture changes using them are staged (`MtkRequestOptions.kt`, `MtkFeature.kt`) but **not built or tested**.
- A package `com.google.android.apps.googlecamera.fishfood` is installed: a Google Camera build is already on the phone. Worth testing whether it opens now that all apps are whitelisted.
- Hard limits: no 4K60 (AE table caps at 30 fps), no OIS, high-speed video tops at 1080p120.

## 2. Does a kernel upgrade improve camera quality? **No** [V]
- Image quality comes from the vendor ISP tuning and algorithm libraries (userspace blobs), not the kernel.
- The kernel only carries sensor drivers (14 sensor drivers in `CUSTOM_KERNEL_IMGSENSOR`, including `s5kgm1st` and `imx519`), ISP/DPE/RSC/MFB/OWE/WPE/FD hardware drivers, flashlight (AW36518) and CCU. All the MFNR/MFB/OWE blocks needed are already enabled.
- Two ISP blocks are off (`GEPF`, `EAF`). Turning them on without vendor HAL support does nothing and can break the camera. Leave alone.
- A different kernel version would break the vendor camera blobs (they expect 4.14 driver interfaces), so it can only make the camera worse.
- Kernel work that **does** help the camera indirectly: a faster memory/CPU path (zram, scheduler) so burst processing does not stall.

## 3. Does a HAL upgrade help? Mostly no [V][R]
- The HAL is the closed MediaTek build. A newer Android HAL interface (AIDL camera) cannot be built without vendor source. Android 16 still accepts the HIDL provider 2.4, so we stay compatible for now. HIDL removal in a future Android release is the long-term risk, not a quality issue.
- What we can touch is the **framework side**: pass the calling app's package name to the HAL (the BlissROMs-style `libcameraservice` vendor tag) so per-app quality gates inside the HAL unlock. Already planned, untested.

## 4. "Camera engines": what can and cannot come to this phone
| Engine | Reality | Verdict |
|---|---|---|
| **Google Pixel HDR+ / Night Sight (GCam)** | App-level multi-frame RAW merge. Needs RAW + burst + manual control, which this HAL has. GCam ports on MTK Helio historically crash or give odd color; newer modded builds with a per-device XML do better. A GCam build is already installed. | **Best computational option; test it** |
| **OnePlus Hasselblad** | Color tuning and processing tied to Qualcomm Spectra ISP and OxygenOS framework libraries. | Not portable |
| **Nothing TrueLens** | In-app AI stack on Nothing's own camera harness and framework extras. | Not portable |
| **Realme / Xiaomi / other OEM camera apps** | Need OEM framework jars and HAL extensions; crash or run degraded on AOSP. | Not portable |
| **iOS / Apple** | Hardware ISP silicon inside Apple SoCs. Nothing to port; no equivalent software. | Impossible |
| **Open Camera** | Free, RAW/DNG, manual, basic HDR. No multi-frame night stacking. | Useful for RAW |
| **LineageOS Aperture** (system app) | CameraX-based, clean; no own computational stack; can use vendor extensions if exposed. We are adding MediaTek MFNR/HDR/AIS/48 MP toggles. | **Our main app** |
| **GrapheneOS Secure Camera** | Same CameraX-extension approach, privacy focus. | Not needed |
| **Open HDR+ re-implementations** (Halide-based reproduction of Google's paper, FOSS stackers) | Research-grade, CPU heavy, slow on 2x A75 + 6x A55. | Lead only, high effort |

## 5. Recommended path to the best quality we can reach
1. **Use the vendor's own pipeline through Aperture** (MFNR/MFB, photo HDR, AIS, 3DNR, EIS, 48 MP). This is silicon-tuned processing, not an app filter. Build, then compare against stock.
2. **Test the installed Google Camera** and one modded GCam with an MTK config XML; keep what works.
3. **RAW/DNG capture** for demanding shots (RAW10 verified), developed later in Darktable/RawTherapee or Lightroom Mobile.
4. **Do not disable any vendor stage** or add other vendors' camera props; that only lowers quality on this HAL.
5. **Measure:** shoot the same scenes (daylight, low light, HDR backlit, 48 MP detail) with stock Micromax firmware photos vs. ours, side by side. Without this we are guessing.
6. Cheap quality fixes outside the camera: the HEVC alignment bug (fixed, AVC default) so recorded video is sharp.

## 6. What stays impossible
4K60, OIS, >120 fps, Hasselblad/TrueLens/iOS processing, any "AI camera engine" that is a closed binary built for another phone's ISP.

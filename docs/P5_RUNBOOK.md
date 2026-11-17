# P5_RUNBOOK.md — mechanical checklist for the tree pass (run the moment
# `repo sync -j6` completes). Feeds STATE.md (P5) and the COMPAT_REPORT SHIM rows.

Preconditions: `STATE.md` phase = P4 done; disk ≥ 25 GB free at all times (watchdog).

## 0. Sync integrity (5 min)
- [ ] `repo status` clean of surprises; `ls branches/device/micromax/` shows
     TreeView of synced yogurt trees (device + vendor 'fourteen', kernel
      'android-15.0', sepolicy_vndr 'arrow-14.0', hardware/mediatek 'lineage-23.2').
- [ ] `git -C <tree> log -1 --format='%H %cd'` per tree → record branch heads in
      STATE.md (reproducibility).
- [ ] `bootable_recovery` @thirteen branch is IN or OUT of the manifest → decision
      (16.2 needs lineage-23.x-compatible recovery; the fork is 13-era ⇒ likely OUT,
      build TreeView native recovery from hardware/lineage lineage).

## 1. Rename-and-shift pass (device tree @16.2)
- [ ] Product makefile: `derp_yogurt.mk` (+ `derp_yogurt_64.mk` if split),
      `$(call inherit-product, vendor/derp/config/common_full_phone.mk)` per the
      DerpFest 16.2 vendor layout; lunch token `derp_yogurt-bp4a-userdebug`.
- [ ] `ANDROMETA AIDs`/`ALLSDK overrides`:
      LUNCH check `list-products` to see naming expectations before editing.
- [ ] `PRODUCT_SHIPPING_API_LEVEL := 29` kept; `ro.vendor.api_level=29` respected in
      `device.mk` (G2: vendor stays R-class on paper).
- [ ] `PRODUCT_COPY_FILES` for `fw` (connsys/MTK) = stock list from DF13 tree.
- [ ] BoardConfig: static `BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432` etc. from
      cross-check vs recon (super 9,126,805,504; boot 32 MB; dtbo 8 MB; recovery 32 MB).
- [ ] ext4 everywhere (BOARD_EROFS_* absent), `BOARD_EXT4_SHARE_DUP_BLOCKS := true`?
      ( discover in tree convention).

## 2. Gate G2 — SHIM row verification (the report rows say SHIM; prove each)
- [ ] `frameworks/base/services/.../fingerprint`: find the HIDL `2.1` → AIDL bridge
      (class Fingerprint21 / sensorProvider HIDL). If absent in 16.2 → port from
      lineage-22/lineage-20 prior or phh treble quirks; file goes v. we track via
      KNOWN_ISSUES §1-2.
- [ ] `system/security/keystore2: km_compat` present and included by the vendor
      (check `vendor//======================================================================`
      for keymaster_compat wiring); keymaster@4.0 sits on it.
- [ ] `frameworks/av/media/libaudiohal`: confirm HIDL audio 6.0 loads (AudioHal*
      tables per impl version) — else restore from 22-lineage helper or port light
      note impl. THIS decides the R2 fate.
- [ ] Telephony: `vendor/lineage/telephony`/`frameworks/opt/telephony` radio HIDL
      1.x bridge + `radio-deprecated` shims (RIL 1.2 + mtkradioex 1.9 remain).
      TelephonyManager expectations at 16.
- [ ] gatekeeper 1.0 consumer inside keystore2 (gk_compat?) — keymint bridging.

## 3. Vendor manifest re-declaration (mechanical)
- [ ] `vendor/micromax/yogurt/.../vendor_manifest.xml` identical to
      recon/vendor_manifest.xml (+10 fragments).
- [ ] Root: `target-level="5"` (empty matrix.5 lane). 12.0 props kept byte-identical
      (§8: `ro.vendor.*` / `persist.vendor.*` untouched from recon getprop).
- [ ] `board/ODM` fragments: `recon/odm_manifest.xml` untouched content.

## 4. First build target sanity
- [ ] `source build/envsetup.sh && lunch` lists `derp_yogurt-bp4a-debug/user/userdebug`.
- [ ] `ccache -M 15G` + `USE_CCACHE=1 CCACHE_EXEC=$(command -v ccache)`.
- [ ] `-j3` builds; `m derp` (+`recoveryimage`+`vbmeta`) once the tree permits.

## 5. Immediately after the build boots-in-principle (static only)
- [ ] §13 gates list run 1-10 (record each PASS line in STATE.md P7).
- [ ] copy zip + sha256 → outputs/ (userdebug first per §11).

Return-value convention: each unchecked box = open item in STATE.md.

## 6. Camera unlock pass (research/CAMERA_RESEARCH.md → mechanics; run together with §3)
Ground truth: HAL is vendor-blob (mtkcam 3.5) — "modifying HALs" = runtime-prop +
framework-tag levers ONLY; no vendor byte is edited (spec rule). Evidence refs:
recon/live_audit/{fp_props.txt, camdump_full.txt}, research/CAMERA_RESEARCH.md.

- [ ] RC-AUX-LIST: device init rc `on early-init` block → `setprop
      vendor.camera.aux.packagelist "*"`. Rationale: stock value (VERIFIED on
      live ROM) = `com.android.camera,com.google.camera,net.sourceforge.opencamera,
      org.lineageos.aperture` — the per-app gate that hides the logical multi
      camera (HAL id 5, the 48 MP remosaic composite) and HAL id 2 from every
      third-party app. Setting `*` before any service starts = the HAL reads
      all-permitted on first open. If the HAL parser rejects `*`, fallback:
      value = stock 4 entries + `com.googleHC,org.pixelexperience.camera,
      com.android.mms,org.codeaurora.camera`, keep `*` suggestions in doc.
- [ ] RC-AUX-SEPOLICY neverallow-clean companion: property_contexts entry for
      `vendor.camera.` (label from built-in vendor property_contexts) + sepolicy
      `allow init <prop_type>:property_service set;` — add exactly ONE allow, no
      attribute abuse; if avc denies at first flash, widen via log not guess.
- [ ] FW-VENDORTAG **SKIPPED WITH PROOF** (was: port BlissROMs 19868). Verified
      against the live camdump tag dictionary: 21 vendor sections, NONE is a
      package-name tag (`grep 'defined in section'` → no `package` hit) — the
      Oplus/Nothing mechanism injects data this blob cannot read. Unlock
      stays RC-AUX-LIST only. Patch retained in research for portability only.
- [ ] MTK-PROCESSING-VERIFY (new): static-chars carry MTK's own burst stacks:
      sections abffeature (AE-bracket fusion ≈ HDR+ analog), mfnrfeature
      (multi-frame NR ≈ night analog), eisfeature, smvrfeature (slow-motion),
      multicamfeature, nrfeature, hdrfeature, vsdoffeature, cshotfeature.
      Post-flash battery: confirm these feature controls stay reachable by
      NON-whitelisted clients after RC-AUX-LIST, and record which camera app
      surfaces each (Aperture/OpenCamera high-speed). No tree change unless a
      client needs a flag — then iterate with logs, never blind props.
- [ ] DO-NOT-TOUCH list (record compliance line in STATE.md): 
      ro.vendor.mtk_slow_motion_support=1, ro.vendor.mtk_zsdhdr_support=1 (both
      VERIFIED already unlocked on live ROM — shipping byte-identical);
      persist.vendor.camera3.pipeline.bufnum.* (Redmi-MT6768 tuning) — SKIPPED:
      wrong-HAL risk of FPS regression; revisit ONLY if post-flash logs show
      pipeline starvation; fpsgo/thermal policy — untouched (vendor perf domain).
- [ ] POST-FLASH camera verify battery (extend post_flash_collect_logs.sh):
      1. `dumpsys media.camera | grep 'public camera devices visible'` → expect
         ≥5 (was 4) = aux unlock worked, else log HAL parser behavior honestly.
      2. camdump grep remosaicenable still present (nothing stripped).
      3. vendor.camera.aux.packagelist getprop value == our rc value.
      4. 1080p120: `dumpsys | grep -A5 'HighSpeed'` unchanged (we only unlock,
         never re-advertise).
- [ ] JPEG quality 100 for all apps — DROPPED per research verdict (HAL-internal,
      vendor-blob🔒); apps set their own JPEG quality param on JPEG streams and it
      passes through unchanged — document in CAMERA_RESEARCH.md §5, no action.
Return-value convention: each unchecked box = open item in STATE.md.

## 7. FPS/EIS surface pass (user directive: enable ALL HAL-documented capability,
    never fake a non-documented one; execute with §6 post-sync)
Ground truth: hs tables = 1080p & 720p @ 30..120 fps; standard AE [5..30];
OIS byte[1]=0 on all 6 devices; EIS modes [0 1] present. Physics-impossible set
(NEVER advertise): 4K60, >120 fps, OIS on any camera.

- [ ] 4K30: no change needed in HAL path; verify first flash record from 2 apps
      (DerpFest camera + OpenCamera) with EIS ON, file clean (no drop warping).
- [ ] 1080p 60: verify via constrained-high-speed pipeline (Camera2 HPV):
      OpenCamera high-speed mode or Aperture slow-motion if present in synced
      tree; fps range [60,60] must come FROM the HS table (30..120 legit subset).
- [ ] 1080p 120 slow-mo: same pass; media encode profile follows vendor caps
      (MediaRecorder high-speed handles set from vendor HTC resolution rows).
- [ ] EIS coverage: keep stabilization [0 1] per camera untouched; confirm
      `dumpsys media.camera` static tables identical to stock after flash.
- [ ] media_profiles: do NOT hand-add bitrate/frames rows for fps the HAL did
      not expose (documents the 4K60 ban at product level too).
- [ ] post-flash log battery (add to post_flash_collect_logs.sh): record 10 s
      at 4K30 + 1080p120, grep logcat for CameraHal dropped-frame/EIS lines,
      attach file stats (fps, size, encoder profile) to outputs/.
Return-value convention: each unchecked box = open item in STATE.md.

## 8. Aperture PRO extension cycle (research/APERTURE_PRO_PLAN.md; SECOND build
    cycle, after first successful boot — never in the first flash)
- [ ] verify synced tree = packages/apps/Aperture (org.lineageos.aperture);
      branch/fetch source → device-repo add-on commits, one per feature.
      Feature order (risk-ascending): Pro mode → RAW toggle → MFB/HDR/AIS
      toggle (query availablemfbmodes etc. at runtime, never hardcode) → 48 MP
      remosaic toggle (dynamic vendortag lookup, graceful absence) →
      constrained-HPV slow-mo (1080p60/120) — LAST, highest complexity.
- [ ] all new code feature-flagged; OFF state == upstream Aperture behavior.
- [ ] regression battery + log attach per APERTURE_PRO_PLAN acceptance list.
Return-value convention: each unchecked box = open item in STATE.md.

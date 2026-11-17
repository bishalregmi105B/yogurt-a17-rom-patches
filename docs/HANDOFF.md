# HANDOFF — DerpFest 16.2 for Micromax IN Note 1 (E7746 / "yogurt")
**Written: Oct 29, 2026, ~14:45 — kick #32 completed the pipeline end-to-end.**

## The deliverable
| File | Size | SHA-256 |
|---|---|---|
| `DerpFest-v16.2-20261029--Community-Stable.zip` | **2,333,905,900 B (~2.33 GB)** | `83f0fe7a066d7013c9f7adf6f2c12fc2a06da61756d20c2fa62b03f6e109cd25` |

Location: this folder (byte-identical copy, sha re-verified post-copy) and the
build tree (`out/target/product/yogurt/`).

## VERIFIED (evidence-based, checked Oct 29)
1. **Zip integrity**: `zipfile.testzip()` = clean, all 7 entries pass CRC.
2. **A/B payload structure**: `payload.bin` 2,333,898,839 B + `payload_properties.txt`
   (FILE_HASH / METADATA_HASH populated) + `META-INF/com/android/metadata(.pb)`.
3. **Device identity**: `pre-device=E7746,E6746,yogurt` — matches your phone.
4. **OS level**: `post-sdk-level=36` (Android 16) / DerpFest 16.2 (BP4A.251205.006),
   security patch 2026-08-01.
5. **`boot.img` + `recovery.img`**: exactly 33,554,432 B each — the wall-20 dtbo
   truncation cap held through the final rebuild.
6. **vbmeta chain**: `vbmeta.img` header **Flags: 3** (verification/hashtree disabled
   — correct for a boot-unlocked retrofit device), with chained
   `vbmeta_system.img` + `vbmeta_vendor.img` (65,536 B each, flags 0 as stamped).
7. **Zip rename + json step**: the build's post-OTA rename to
   `DerpFest-v16.2-…zip` succeeded; the .json generator died on an empty device
   variable (wall 25, below) — **the json is optional; the zip is the flashable**.

## UNTESTED (honest — requires the phone, which stays read-only until you flash)
- **Nothing has touched a live device yet.** All verification above is file-level.
- Runtime behavior unknowns (UBL flashing is a one-way street; read `BACKUP_FIRST.md`,
  `RESTORE_STOCK.md`, `INSTALL.md` first):
  - fingerprint HAL behavior on real TEEI hardware (userspace halves of walls 12–19 are in-tree;
    kernel-side fixes arrive with the Phase-2 source-built kernel);
  - camera profile behavior (4K30 claimed by HAL; real capture **UNTESTED**;
    4K60/OIS are physically impossible per `HARDWARE_MAX.md`);
  - modem/ims call path, NFC-less package, sensor stack, battery life.
- Predicted first-boot: 5–15 min inactivity (dexopt/app ops migration), then stable.
  Use `post_flash_collect_logs.sh` for the acceptance battery
  (`sys.init.updatable_crashing` empty; `lshal` fingerprint HALs; camera profiles).

## Flash path (summary — full text in INSTALL.md)
1. `BACKUP_FIRST.md` **first** (data is not guaranteed across clean-flash).
2. Boot to stock recovery / fastboot-boot recovery.img, wipe data.
3. `adb sideload DerpFest-v16.2-20261029--Community-Stable.zip`.
4. After first boot: run `post_flash_collect_logs.sh`, send me the log dir.

## Wall ledger — final (walls 1–25, all self-forged and in-tree)
Walls 1–21: see `STATE.md` (sepolicy, rc, boot-jars, recovery truncation, VINTF flag).
- **23a/23b/23c** — device-HAL instances unacknowledged → 27-block/62-instance
  framework compat matrix (extracted verbatim from the checker's own failure dump;
  `$()` → literal path; `<instance>`-explicit ⇒ checker consumed it silently).
- **24** — `META/ab_partitions.txt` missing → `AB_OTA_PARTITIONS := boot vbmeta
  vbmeta_system vbmeta_vendor dtbo system vendor product` in `derp_yogurt.mk`.
  (This is also a *soong*-config var: cost one full 128-min re-analysis.)
- **25** — post-zip `Generating .json` died: `out/target/product//system/build.prop`
  (empty device var inside the zip-tool step). Optional nicety only; regeneratable
  in any later cycle. Patch archived: `/tmp/opencode/rombuild_research/WALL25*` if
  captured, else in-tree `KickBuildJson` device additions.

## Machine state / next phase
- **Machine stays ON** (user instruction; sentinel disarmed — no auto-poweroff).
- Kick #32 total: 3h22m (includes the 128-min soong full re-analysis for the wall-24
  soong var + full packaging).
- Next: (a) regenerate "*.json" via one in-tree fix (cheap, non-essential),
  (b) Aperture-PRO camera merge → `m Aperture` → `m derp` (input-class, no soong
  regen), (c) **Phase-2 source-built kernel** from `SakthivelNadar/yogurt`
  @ `yogurt-q-oss` (census + ladder: `research/KERNEL_SOURCE_DISCOVERY.md`),
  (d) `post_flash_collect_logs.sh` on your flash.

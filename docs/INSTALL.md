# INSTALL — DerpFest for Micromax IN Note 1 (yogurt / E7746)

> Read BACKUP_FIRST.md and RESTORE_STOCK.md completely before starting.
> This file is finalized in Phase P8 with the real artifact names + SHA-256s;
> the flow below is fixed and will not change.

## 0. Requirements
- Phone: bootable (stock or DerpFest 13 both OK), battery ≥ 60 %.
- PC with `adb` + `fastboot` installed; USB data cable.
- Artifacts from `outputs/IN_NOTE_1_DERPFEST/`:
  OTA zip, `recovery.img`, `boot.img`, `dtbo.img` (if regenerated),
  `vbmeta.img` (verity/verification disabled build), and a custom recovery with
  `adb sideload` + fastbootd (dynamic-partition aware).

## 1. Backups (mandatory)
Follow BACKUP_FIRST.md. Do not proceed without the nv-partition set archived
off-device, IMEI screenshots taken, and the stock zip + SHA-256 verified.

## 2. Unlock / check bootloader state
- Read state (read-only, any time):
  `adb shell getprop ro.boot.flash.locked` (0 = unlocked)
  `adb shell getprop ro.boot.vbmeta.device_state` (unlocked / locked)
- If still locked: follow Micromax IN Note 1 official unlock guide (fastboot
  `oem unlock` style; it wipes data once). Document that state changes
  `orange` verified boot state permanently.

## 3. Flash recovery + disable-verity vbmeta
```bash
fastboot flash recovery recovery.img
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
```
- If the vendor image expects `vbmeta_system`/`vbmeta_vendor` split and both files
  ship in this bundle: flash them the same way **from the bundle**, in the order
  listed in INSTALL's artifact list.
- `--disable-verity --disable-verification` is required because the ROM's product
  images are not signed with Micromax/Google release keys.

## 4. Boot the new recovery
`adb reboot recovery` or (power + VOL-UP) → "Recovery". Expect the Lineage-style
recovery splash. If instead you see the old Treble/stock recovery: you flashed the
wrong slot/image — re-flash and power-cycle before anything else.

## 5. Format data (once, now — mandatory when switching FBE policy/keystore keys)
Recovery → Factory reset → **Format data/factory reset** → confirm.
Do NOT confuse with "wipe cache". Formatting the FBE-encrypted data partition is
REQUIRED on a ROM change (a mismatch otherwise = boot loop).

## 6. Sideload the ROM zip
On recovery main menu: **Apply update → Apply from ADB** → PC side:
```bash
adb sideload DerpFest-<ver>-<date>-yogurt-E7746.zip
```
- If it stops at ~47 %: that is the signature-verify restart (normal). Do not unplug.
- Back out only after it returns to the recovery menu.

## 7. Optional: re-flash modules
- When both vendor vbmeta fragments are used, re-check the flag pair before reboot.
- (First-boot collection below.)

## 8. First boot
- Expect 2–6 minutes (first-time dexpreopt + FBE init). Screen: DerpFest logo +
  spinner; second boot often faster.
- When you land on Setup: start WITHOUT Wi-Fi first if you plan to test sensors
  (fingerprint!) offline first.

## 9. Immediately: run the log collector
```bash
adb shell settings put global stay_on_while_plugged_in 7   # keep awake
bash post_flash_collect_logs.sh                        # from this folder
```
This writes `post_flash_logs_<timestamp>/` (logcat, dumpsys, lshal, dmesg, props,
services). Zip and send it back per the handoff instructions — it drives the next
bring-up iteration (see KNOWN_ISSUES.md watch-list).

## 10. Sanity matrix for the first boot (do these and record pass/fail)
fingerprint ENROLL FIRST (with a wiped finger, clean lens), Wi-Fi, mobile data +
dual-SIM, VoLTE (dial, speak, hang up), hotspot toggle, GPS lock outdoors, camera
rear (all four lenses open in the stock-era camera app if shipped) + front, BT
pairing + A2DP, speaker + earpiece + headset + Assistant button, vibration,
charging (notifies + fast charge), microSD mount, USB MTP + ADB re-enumerate,
Widevine check in a streaming app, and battery-drain warm idle checkpoint.
Record results in the log you send back.

# BACKUP_FIRST — Micromax IN Note 1 (E7746 / yogurt)

> READ THIS FULLY BEFORE TOUCHING ANYTHING. If a step below is impossible to do
> right now, stop and finish it first. There is no path back to a working phone
> after a bad flash unless these exist.

## 0. Why

This phone has an MTK modem whose **IMEI + calibration live in special flash
partitions**. Formatting /data, flashing a wrong preloader, or even bad recovery
events can destroy `nvram`/`nvdata`/`nvcfg`. Without backups, even SP Flash Tool
cannot always bring the IMEI back (the one thing that usually survives is
`preloader`, but modem calibration cannot be rebuilt from nothing).

## 1. What this device's partition map actually is (extracted read-only from your
phone, 2026-10-25) — `/dev/block/by-name` (gpt, A-only, no super-slot):

boot, dtbo, recovery, super, vbmeta, vbmeta_system, vbmeta_vendor, userdata,
protect1, protect2, seccfg, proinfo, nvram, nvdata, nvcfg, persist, para, expdb,
mmc0blk1(?), frp, metadata, misc, boot_para, odmdtboimg (no odm dynamic split),
etc. (Full list in recon/? see the by-name listing captured earlier: pgs)
**You must back up, at minimum (in SP Flash-Tool terms):**
`nvram`, `nvdata`, `nvcfg`, `persist`, `proinfo`, `seccfg`, `protect1`, `protect2`,
`preloader` (if offered), `frp`.

## 2. Best options, in order of preference

### 2a. MTKClient (recommended — works with or without unlocked bootloader)
Requires: Windows or Linux PC, USB data cable.
1. Turn OFF the phone.
2. Install MTKClient per its README (linux: `git clone
   https://github.com/bkerler/mtkclient; cd mtkclient; pip3 install -r
   requirements.txt; apt-get install libusb-1.0-0` etc.).
3. Put the phone in **BROM mode**: hold both VOLUME- (or the tool prompts); plug in
   USB with phone OFF. MTKClient must start before the phone boots Linux.
4. In the GUI/CLI: **Read firmware/all partitions** → save a full dump plus
   individual partitions. Save BOTH.
   (In CLI: `python mtk da vbmeta_dump ..` or simply
   `python mtk r boot,recovery,vbmeta,super,protect1,protect2,seccfg,proinfo,nvram,nvdata,nvcfg,persist,frp,preloader ./bk/`)
5. Keep these files OFF the phone, on your PC + a USB stick. Do not delete them.

### 2b. SP Flash Tool readback (Windows-friendly, no root needed)
1. Get the scatter file from your community sources or generate one with the
   earlier recon (partition map).
2. SP Flash Tool → "Readback" tab → Add → set `EXT lenght` and address to read each
   critical partition. (SP MTK "Readback" reads by address; get offsets from the
   scatter/PGT.) Back up at minimum the partitions in §1.
3. Keep them offline.

### 2c. If the bootloader is already unlocked and you ever get boot (or have
recovery now): TWRP/PBRP-style backup of `Boot/Vendor`, plus `adb pull` of
`/persist`, and a copy of IMEI value shown in stock **Settings → About → IMEI 1/2**
and IMSI (call service (* # 06 #) — screenshot before you flash anything). Keep a
photo of the IMEI sticker under the battery as second reference.

### 2d. What NOT to skip even if you think data is expendable
- **IMEI partitions** (nvr/nvcfg/proinfo). A fresh Android on a wiped IMEI state is
  not fixable without them or paid hardware.
- **FBE data**: after reproducing keystore, format data is part of flashing anyway
  (INSTALL.md) — so also back up what you value from userspace (photos, chats) by
  any ordinary way before starting, because FORMAT DATA will wipe the phone.

## 3. After backup — checklist before flashing anything
- [ ] backed-up `nvram/nvdata/nvcfg/persist/proinfo/seccfg/protect1/protect2/frp` verified non-zero sizes
- [ ] off-device copy (PC + second medium)
- [ ] bootloader status confirmed (`adb shell getprop ro.boot.flash.locked` — on
      this phone BACKUPS ABOVE ARE JUST AS NECESSARY even when unlocked)
- [ ] battery ≥ 60 %
- [ ] stock-restore zip downloaded + SHA-256 verified (see RESTORE_STOCK.md)

# RESTORE_STOCK — Micromax IN Note 1 (E7746 / full_k69v1_64)

## 1. The archive (VERIFIED 2026-10-25)

| Field | Value |
|---|---|
| File | `Micromax_IN_Note_1_E7746_MT6768_SW_V12.0_HW_V2.0_070121.zip` |
| Build | full_k69v1_64-user, Android 10 (`QP1A.190711.020` family — matches the vendor gen your phone reports) |
| Size | **1,861,502,075 bytes (1.8 GB)** |
| SHA-256 | `f0affe0b2e2246da7bfc1b6d1dfc0684ccd76942f2bd137e9f46f95e0af55e1d` |
| Source | MediaFire mirror of the FirmwareFile V12.0 release, fetched 2026-10-25 |
| Source URL | https://www.mediafire.com/file/2ftunffcuoioo23/Micromax_IN_Note_1_E7746_MT6768_SW_V12.0_HW_V2.0_070121.zip/file |
| Verification | hash recomputed locally twice (scraper pass + independent pass), both matches |

The zip is stored under `downloads/` on the build volume; keep a personal off-device
copy too (USB drive / NAS) — that is your only full-restore guarantee.

## 2. What this restores

- SP Flash Tool scatter-based MTK firmware: preloader, lk, boot, recovery, system,
  vendor, super (2022-era stock zips ship either stock-flavor `system.img` sparse
  super layouts or separate system/vendor images depending on generation; open and
  check the zip's scatter before assuming).
- Returning to fully stock also returns **AVB/vbmeta to normal/enforcing state**.
- *Your phone currently runs community DerpFest 13, not stock — the stock zip is
  still the correct restorer because MTK preloader/lk pair and MTK DA auth come from
  the same stock release; always restore firmware that matches your hardware rev
  (HW_V2.0 all builds).*

## 3. How to flash stock back (SP Flash Tool, Windows or Linux)

1. Install the MTK USB serial/VCOM drivers (USBPorts/driver installation in device
   manager; SP Flash Tool bundled drivers work).
2. Launch **SP Flash Tool**, choose the radio button **"Download Only"**. Load the
   `MTK_AllInOne_DA.bin` agent + the scatter from the zip (`MT6768_Android_scatter.txt`
   or similar).
3. Turn the phone OFF (remove battery not possible; just power off + hold VOL-DOWN
   while pressing — MTK preloader entry).
4. Plug the USB cable: SP Flash Tool should start writing bars at each
   partition. **Do not select preloader unless your tool branch requires it
   (read the zip's README/Help file if included; if in doubt, uncheck preloader to
   reduce brick risk).**
5. Wait for the green "Download OK" popup; boot once to stock before re-flashing any
   custom ROM.
6. If the device was ever FRP-locked (the `frp` partition persists across flash), the
   first stock boot will ask for the previously synced Google account — logging in
   with the original account clears it.

## 4. How to restore without SP Flash Tool (only if the bootloader is already unlocked)

- **fastboot** (from an MTK bootloader after unlock):
  `fastboot flash boot boot.img`, `fastboot flash recovery recovery.img`,
  `fastboot flash vbmeta vbmeta.img` (or `fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`
  if you want custom ROMs to boot), `fastboot flash super super.img`.
- **fastbootd** (userspace fastboot) is required for dynamic partitions (`system`,
  `vendor`, `product` inside super): boot into recovery, select "Enter fastboot",
  then `fastboot flash system system.img` etc.
- NOTE: if the CURRENT boot chain is broken pre-bootloader (preloader/lk), the only
  recovery path is SP Flash Tool + (worst case) authorized preloader tool.

## 5. If the ROM does not boot (troubleshooting ladder)

1. Boot into recovery (VOL-UP + POWER, or VOL-UP while plugged). Format data
   (FBE mismatch after ROM change is the most common cause of boot loops).
2. If still looping: sideload the same zip again (bad flash possible).
3. If SD-card or recovery states differ: reflash `vbmeta` **with** disable flags
   per INSTALL.md.
4. If ALL else fails: restore full stock per §3. Then read KNOWN_ISSUES.md for
   the "reported-boot behavior" to compare.

## 6. IMEI protection notes (mtk)

- IMEIs live in `nvram/nvdata` (NVRAM partition). SP Flash Tool "**Format all + auto
  download**" WILL wipe them — NEVER use "Format all + Download". Always
  "Download only". If you must use "Format all" after a corrupt nvram, restore your
  archived nvram/nvdata backups afterward via MTKClient write (or a "Format except
  bootloader" flow that misses nvram/nvdata).
- Check IMEIs right after any format: `*#06#`.

## 7. Files matching this build

| Purpose | File |
|---|---|
| restore zip | downloads/Micromax_IN_Note_1_E7746_MT6768_SW_V12.0_HW_V2.0_070121.zip |
| SHA-256 | see block appended below |
| scatter (reference copy) | downloads/stock_v12_ref/MT6768_Android_scatter.txt |
| stock boot/recovery/dtbo/vbmeta refs | downloads/stock_v12_ref/*.img (hashed) |
| Checksum.ini | downloads/stock_v12_ref/Checksum.ini |

## 8. PARTITION-TABLE WARNING — read before any SP Flash Tool session (2026-10-25)

The V12.0 scatter file declares `super = 0x100000000` (4 GiB). **Your phone's real
`super` is 0x21FF00000 (9,126,805,504 B ≈ 8.5 GiB)** — measured on-device during
recon and consistent with community OTA op-lists (group max 9,122,611,200 B).
The 2021 scatter predates the partition-table revision on shipping units.

Meaning:
- **"Download Only" is safe** — it writes partition *contents* (preloader, lk, boot,
  recovery, vbmeta family, super image blob) and does NOT rewrite the GPT.
- **"Format All + Download", "Format except bootloader", or anything that rewrites
  PGPT with THIS scatter is NOT safe** — it would truncate `super` to 4 GiB and
  strand the rest of the eMMC (and risk nvram/nvdata loss, IMEIs included; see §6).
- After restoring stock with Download Only on a hardware-rev-2.0 unit, all stock
  mounts still fit inside a ≤4 GiB super, so the ROM boots normally.
- If you ever need full partition-table surgery, that is MTKClient territory and
  requires your own nvram/nvdata backups — out of scope for this ROM project.

## 9. What else ships inside this zip (worth knowing)

- Full MTK image set: `preloader_k69v1_64.bin`, `lk-verified.img`, `md1img`,
  `scp`, `sspm`, `spmfw`, `tee` — the complete stock boot chain.
- `Firmware/Firmware/vmlinux` (231 MB, unstripped) — stock kernel reference used
  by the builder for Phase-2 config cross-checks (kept inside the zip).
- `database/APDB`/`MDDB` — RF/AT calibration data (never modified).
- `googlekey/` — vendor attestation keys: NOT extracted, NOT used, NOT shipped;
  they live only inside the hashed zip on this machine.
- `boot-debug.img` — stock engineering boot image (reference only).

---
```
SHA-256 (verified twice, 2026-10-25):
f0affe0b2e2246da7bfc1b6d1dfc0684ccd76942f2bd137e9f46f95e0af55e1d  Micromax_IN_Note_1_E7746_MT6768_SW_V12.0_HW_V2.0_070121.zip
size: 1861502075 bytes (1.8 GB)
```

**Reminder:** verify this hash on YOUR copy before trusting it — `sha256sum` must
print the exact line above. If it matches, and the archive tests clean
(`unzip -t`), the restore path in §3/§4 is safe to follow.

# yogurt 4.19 kernel bring-up plan (side track)

> [!IMPORTANT]
> Nothing here touches the running ROM build. All sources live in `/mnt/rombuild/.side_kernel419/`, which is marked `.out-of-tree` and `.find-ignore`. No kernel is compiled until `m derp` finishes, because RAM (14.8 GB) and swap are already saturated.

## Sources

| Role | Repo / branch | Local path (under `.side_kernel419/`) | Kernel |
|---|---|---|---|
| Base | bengris32/android_kernel_mediatek_4.19 (`lineage-23.2`) | `kernel_mtk_419_base` | 4.19.325 |
| Reference | LineageOS/android_kernel_xiaomi_mt6768 (`lineage-24.0`) | `ref_kernel_xiaomi_mt6768` | 4.19.325 |
| Reference | xiaomi-mt6785-dev/android_kernel_xiaomi_mt6785 | `ref_kernel_xiaomi_mt6785` | 4.19.325 |
| Device-tree reference | kardebayan/android_device_realme_nemo (`seventeen`) | `device_realme_nemo` | n/a |
| Current kernel | `kernel/micromax/yogurt` (OEM + patches) | in the ROM tree | 4.14.141 |

## Findings

- The 4.19 base already has `k68v1_64_k419_defconfig`, `k69v1_64_k419.dts` and `mt6768.dts`. Yogurt currently appends `mediatek/mt6768` and overlays `k69v1_64`, so the platform lines up.
- Yogurt and nemo use the same boot-image layout: header v2, base `0x40078000`, tags offset `0x0bc08000`, page size 2048, `Image.gz`, cmdline `bootopt=64S3,32N2,64N2`. A 4.19 `Image.gz` can be repacked without changing the layout.
- nemo is MT6785 (`k85v1_64_k419_defconfig` plus `vendor/nemo.config`). Reuse its pattern (a defconfig fragment, `BOARD_DTBO_CFG`, `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`), not its drivers or DTS.
- Yogurt ships prebuilt `dtb.img` and `dtbo.img` (in `device/micromax/yogurt/prebuilts/`), built for 4.14. They must be rebuilt from the 4.19 DTS.

## Micromax-specific drivers to port

| Driver | In 4.19 base | Reference repo | Yogurt 4.14 source (fallback) |
|---|---|---|---|
| LCM `hx83112b_fhdp_dsi_cmd_auo_rt5081` | yes | n/a | n/a |
| LCM `otm1911a_fhdp_dsi_vdo_truly_rt5081` | yes | n/a | n/a |
| LCM `ft8756_fhdp_dsi_vdo_tcl` | no | Lineage mt6768 has a different variant, `panel-truly-ft8756-vdo.c` | `drivers/misc/mediatek/lcm/ft8756_fhdp_dsi_vdo_tcl/` |
| Sensors `imx519`, `s5k2t7sp`, `s5k2p7`, `ov8856`, `imx386`, `imx398`, `s5k2l7`, `gc5035` | yes | n/a | n/a |
| Sensor `s5kgm1st` | no | Lineage has a close match, `s5kgm1sp_sunny` | `imgsensor/src/common/v1_1/s5kgm1st_mipi_raw/` |
| Sensor `gc8034sub` | no | Lineage has `gc8034_mipi_raw` | `imgsensor/src/common/v1/gc8034sub_mipi_raw/` |
| Sensors `ov16a10`, `ov16a1q`, `bf2253L`, `bf2253Lmacro` | no | not found | `imgsensor/src/common/v1_1/<name>_mipi_raw/` |
| Smart amplifier `aw88194` (`SND_SMARTPA_AW88194A_NEW`) | no | not found | `sound/soc/codecs/aw881xx/aw88194*` and `drivers/misc/mediatek/smartpa/aw88194a` |
| Fingerprint `ft9362` (TEE, `FT9362_FINGERPRINT_TEE`) | no | not found | `drivers/input/fingerprint/focaltech_tee/` (Kconfig and Makefile entries in `drivers/input/fingerprint/`) |
| PMIC `mt6358` | yes | n/a | n/a |

The yogurt `k69v1_64.dts` has the `aw88194a` entry under `&i2c7`. Port the DTS nodes together with the drivers.

## Phases

1. **Prep (after the ROM build ends):** copy `kernel_mtk_419_base` to a working tree. Create `arch/arm64/configs/yogurt_k419_defconfig` from `k68v1_64_k419_defconfig`, with the hardware options from the 4.14 `yogurt_defconfig` merged in as a fragment, `vendor/yogurt.config`, in the same style as nemo's `vendor/nemo.config`.
2. **Port drivers:** bring in the missing drivers listed above. Imgsensor and LCM files are mostly self-contained, but the 4.19 build rules and struct signatures can differ from 4.14, so fix compile errors one driver at a time.
3. **DTS:** build `yogurt_k419.dts` (based on `k69v1_64_k419.dts`) with the Micromax panel, touch, camera and I2C nodes copied from the 4.14 `k68v1_64.dts` and `k69v1_64.dts`. Generate a new `dtbo.img`.
4. **Compile:** use the toolchain already in the ROM tree (`prebuilts/clang`). Build only `Image.gz` and the DTBs, with low parallelism.
5. **Repack the boot image:** `mkbootimg --header_version 2 --base 0x40078000 --kernel_offset 0x8000 --tags_offset 0x0bc08000 --pagesize 2048`, using the new kernel and the ramdisk from the existing ROM `boot.img`. Check the result stays under `BOARD_BOOTIMAGE_PARTITION_SIZE` (33,554,432 bytes). Keep `vbmeta` flags 3 so AVB is not enforced.
6. **Test:** boot with `fastboot boot` first (no flash). Collect `last_kmsg` or `pstore` and `dmesg`. Flash `boot` and `dtbo` only after it boots. Keep a stock 4.14 `boot.img` as the rollback.

## Risks

- Vendor userspace (HALs, firmware, the `vendor` image) was built for 4.14, and the MTK 4.19 kernel interfaces differ in places (ccci, ged, camera and display ioctls). Expect to debug display, camera and modem first.
- The nemo and Xiaomi references are different phones, so copy only the patterns, not device-specific values.
- Per-phase size limits: `super.img` must stay at or under 4,290,772,992 bytes. This plan doesn't change it, because only boot and dtbo are replaced.

## Status

- [x] Sources cloned (all four reference repos)
- [x] Driver gap analysis complete
- [x] Ported camera sensors & board config (`commit 41e80beb7`)
- [x] Ported LCM display panel & power helpers (`commit 35bd7fd0e`)
- [x] Ported Microtrust TEE v300, FT9362 fingerprint, and AW88194 SmartPA (`commit a0023a225`)
- [ ] Prepare `vendor/yogurt.config` defconfig fragment
- [ ] Author `yogurt_k419.dts` device tree
- [ ] Standby: Wait for ROM build completion before compiling kernel or repacking boot.img
- [x] Sources cloned (all four, including `xiaomi_mt6785`, which is also 4.19.325)
- [x] Driver gap analysis
- [x] Locate `ft9362` source
- [ ] Wait for the ROM build to finish
- [ ] Phases 1 to 6

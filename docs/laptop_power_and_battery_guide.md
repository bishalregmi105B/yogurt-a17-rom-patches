# Dell Vostro 3520 - Power, Battery Bypass & Performance Guide

This document records the exact system configuration, sysfs node mappings, and user control commands for battery bypass charging and performance profiles on your **Dell Vostro 3520** laptop running Linux.

---

## 1. Quick Command Reference

The utility is installed at [`/home/bishal-regmi/.local/bin/laptop_power_control`](file:///home/bishal-regmi/.local/bin/laptop_power_control) (and mirrored at [`/mnt/rombuild/laptop_power_control.sh`](file:///mnt/rombuild/laptop_power_control.sh)).

| Action | Command | What It Does |
|:---|:---|:---|
| **Check Telemetry** | `laptop_power_control status` | Displays battery status, current (mA), thresholds, CPU profile, turbo, and fan RPM |
| **Enable Bypass (Protect)** | `laptop_power_control protect` | Enforces **75% start / 80% cut-off** threshold; cuts battery current, powers via AC pass-through |
| **Reset to Default** | `laptop_power_control reset` | Restores standard charging behavior up to **100% full capacity** |
| **Max CPU & Fan Boost** | `laptop_power_control boost` | Engages `performance` profile, EPP `performance`, Intel Turbo Boost (up to 4.40 GHz) |
| **Balanced Mode** | `laptop_power_control balanced` | Reverts CPU and power profile to balanced mode |
| **Power Saver** | `laptop_power_control saver` | Drops CPU clock ceilings for battery longevity |

---

## 2. Hardware Architecture & Verification

### Battery Bypass Mechanics
- **Embedded Controller (EC)**: Dell uses an onboard ACPI EC battery charging controller.
- **Direct Pass-Through**: When the battery reaches the cut-off threshold (`80%`), the EC halts current flow into the battery cells (`curr1: 1.0 mA`).
- **Motherboard Power Path**: The AC adapter powers the system rails directly (VSYS). This completely prevents high-voltage electrolyte degradation and cell swelling while plugged in indefinitely.

### Verified Sysfs & D-Bus Nodes
- **End Threshold**: [`/sys/class/power_supply/BAT0/charge_control_end_threshold`](file:///sys/class/power_supply/BAT0/charge_control_end_threshold) (`80` when protected, `100` on reset).
- **Start Threshold**: [`/sys/class/power_supply/BAT0/charge_control_start_threshold`](file:///sys/class/power_supply/BAT0/charge_control_start_threshold) (`75`).
- **UPower D-Bus Property**: `org.freedesktop.UPower.Device.ChargeThresholdEnabled` (`true`).
- **CPU Governor**: Intel P-State with Energy Performance Preference (EPP) = `performance` across all 8 logical cores.
- **Fan Monitor**: [`/sys/class/hwmon/hwmon5/fan1_input`](file:///sys/class/hwmon/hwmon5/fan1_input) via `dell_smm` (running ~3,250 RPM; max 5,800 RPM).

---

## 3. Storage Cleanup Summary

- **Initial Root Free Space**: **16 GB** (95% full).
- **Post-Cleanup Root Free Space**: **24 GB** (92% used) — **+8 GB reclaimed**.
- **Cleaned Components**:
  1. Removed orphaned Docker images (`mtkbuild:latest`, `node:22-alpine`, `ubuntu:latest`, `ubuntu:24.04`) and builder cache layers (~3.0 GB).
  2. Removed legacy cached Gradle 8.14 distribution from October (~5.2 GB in `~/.gradle/caches/8.14`).
  3. Purged stale application crash dumps from `/var/crash/`.

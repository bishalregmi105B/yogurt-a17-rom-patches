#!/bin/sh
# post_flash_collect_logs.sh — DerpFest 16.2 for yogurt (Micromax IN Note 1 / E7746)
# READ-ONLY collection from the FLASHED device. Never reboots, never writes to the
# device, never flashes anything. All data is scrubbed via adb shell reads
# (getprop/cat/ls/dumpsys/logcat -d) into host files, then one host-side zip.
#
# usage: ./post_flash_collect_logs.sh [--root] [OPTIONAL-ADB-SERIAL]
#   --root: additionally run "adb root" first (userdebug build only) so dmesg and
#           /sys/fs/pstore can be read. Root is used for shell reads only; on a
#           `user` build those steps simply return "permission denied".
#           (No root is used while the phone still runs the OLD install; this
#           script is meant for the device after the new ROM is flashed.)
#   no arguments: uses the single connected device (or SERIAL env var).
set -u

WANT_ROOT=0
SERIAL="${SERIAL:-}"
for a in "$@"; do
  case "$a" in
    --root) WANT_ROOT=1 ;;
    "") ;;
    *) SERIAL="$a" ;;
  esac
done

# C() = adb wrapper with optional serial. r() = read a device command into a file.
C() { if [ -n "$SERIAL" ]; then adb -s "$SERIAL" "$@"; else adb "$@"; fi; }

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST_DIR="$SELF_DIR/post_flash_logs"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$DEST_DIR/logs_$STAMP"
mkdir -p "$OUT" || exit 2

say() { printf '\n==== %s ====\n' "$1" | tee -a "$OUT/summary.txt"; }

# 0. device sanity — read-only probes, up to ~90 s each stage
timeout 90 adb wait-for-device || { say "adb: no response (wait-for-device timeout)"; exit 1; }
state="$(C get-state 2>&1 || true)"
say "adb state: $state (want 'device')"

booted="$(C shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)"
i=0
while [ "$booted" != "1" ] && [ "$i" -lt 90 ]; do
  sleep 10; i=$((i+1))
  booted="$(C shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)"
done
say "sys.boot_completed: '${booted:-not-1}' after $i probes"

say "battery: $(C shell dumpsys battery 2>/dev/null | grep -E 'level|status' | tr '\n' ' ')"

if [ "$WANT_ROOT" = "1" ]; then
  say "adb root result: $(C root 2>&1 | tr -d '\r\n')"
  sleep 3
fi

# r <local-file-basename> <remote-shell-command>
r() { local f="$OUT/$1"; shift
  printf '# cmd: %s\n# device-time: %s\n' "$*" "$(date)" > "$f"
  C shell "$@" >> "$f" 2>&1
  printf '  %s: %s lines\n' "$1" "$(wc -l <"$f")" 2>/dev/null | tail -n1
}

# 1. static identity + framework state
r  props_full.txt getprop
r  cmdline.txt cat /proc/cmdline
r  uname.txt uname -a
r  service_list.txt 'service list'
r  lshal.txt 'lshal'
r  vintf_vendor.txt 'cat /vendor/etc/vintf/manifest.xml /vendor/etc/vintf/manifest/*.xml /odm/etc/vintf/manifest.xml 2>/dev/null'
r  fstab.txt 'cat /vendor/etc/fstab* 2>/dev/null'
r  selinux_mode.txt getenforce
r  selinux_booleans.txt 'getsebool -a'
r  ro_type_id.txt 'id; getprop ro.build.type; getprop ro.build.fingerprint; getprop ro.vendor.build.fingerprint'

# 2. logs (dump, not follow)
r  logcat_all.txt 'logcat -d -b all -v threadtime'
r  logcat_crash.txt 'logcat -d -b crash,-s events -v threadtime'
r  avc_denials.txt 'logcat -d -v color=none 2>/dev/null | grep -E "avc:.*denied" | tail -n 4000'

# 3. targeted dumpsys reads (rename exec'd names as files)
for s in fingerprint biometric sensorservice telephony.registry keystore \
         media.drm media.audio_flinger media.camera audio wifi location \
         battery thermal power package; do
  r "dumpsys_${s//./_}.txt" "dumpsys $s"
done

# 4. fingerprint/vendor hardware state — lists and small configs only
r ls_dev.txt 'ls -l /dev | grep -iE "fp|finger|focal|goodix|tee|tui"'
r ls_vendor_bin_hw.txt 'ls -l /vendor/bin/hw /odm/bin/hw 2>/dev/null'
r ls_vendor_lib_hw.txt 'ls -l /vendor/lib64/hw /vendor/lib/hw /odm/lib64/hw /odm/lib/hw 2>/dev/null'
r ls_firmware_fp.txt 'ls -l /vendor/firmware 2>/dev/null | grep -iE "fp|finger|focal|goodix"'
r ls_tee_dirt.txt 'ls -l /vendor/app/mcRegistry /vendor/thh 2>/dev/null | head -n 300'
r ls_init_dirs.txt 'ls -l /vendor/etc/init /vendor/etc/init/hw 2>/dev/null'
r cat_fp_inits.txt 'cat /vendor/etc/init/*fingerprint* /vendor/etc/init/*focal* 2>/dev/null'
r zram_stat.txt 'cat /sys/block/zram0/mm_stat /sys/kernel/mm/swap/props 2>/dev/null'

# 5. privileged reads (userdebug + --root only)
if [ "$WANT_ROOT" = "1" ]; then
  r dmesg.txt 'dmesg'
  r pstore.txt 'cat /sys/fs/pstore/* 2>/dev/null'
fi

say "collect complete; zipping into $DEST_DIR"
( cd "$DEST_DIR" && zip -9 -q -r "logs_$STAMP.zip" "logs_$STAMP" || tar czf "logs_$STAMP.tar.gz" "logs_$STAMP" )
( cd "$DEST_DIR" && (sha256sum "logs_$STAMP.zip" 2>/dev/null || sha256sum "logs_$STAMP.tar.gz") )
say "done: $DEST_DIR/logs_$STAMP.(zip|tar.gz) — send this back for iteration 2"

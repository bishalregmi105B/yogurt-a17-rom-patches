# Micromax IN Note 1 (yogurt) – DerpFest 17 / Android 17 patch backup
Backup of every local change made on top of the synced AOSP/Lineage/DerpFest tree.
- `BASE_SHAS.txt`  : repo path, base commit, remote for each patched AOSP repo.
- `patches/`       : `git diff HEAD --binary` per repo; apply with `git -C <repo> apply <patch>` at the base SHA.
- `untracked/`     : new files that were not tracked by git (same relative paths).
- `docs/`          : state notes, research, plans, audits.
- `ci_artifacts/cil`: compiled SELinux CIL files used for the boot-hang fix.
Not included (re-download): prebuilts/clang r353983c, PrebuiltGmsCore.apk (217 MB).
Device/vendor/kernel live in their own repos (branch `seventeen`):
bishalregmi105B/android_device_micromax_yogurt, android_vendor_micromax_yogurt, yogurt (kernel).
Final signed sideload ROM zip is attached to the GitHub release.

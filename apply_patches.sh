#!/usr/bin/env bash
set -euo pipefail

# Applies all DerpFest 17 (Android 17) patches and untracked files onto a synced ROM tree.
# Usage: ./apply_patches.sh /path/to/derpfest17_root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROM_ROOT="${1:-$(pwd)}"

if [ ! -d "$ROM_ROOT/.repo" ] || [ ! -f "$SCRIPT_DIR/BASE_SHAS.txt" ]; then
  echo "Usage: $0 /path/to/derpfest17_root" >&2
  exit 1
fi

echo "==> Applying tracked repo patches from $SCRIPT_DIR/patches -> $ROM_ROOT"
while read -r repo_path base_sha remote_url; do
  [ -z "${repo_path:-}" ] && continue
  patch_name="${repo_path//\//_}.patch"
  patch_file="$SCRIPT_DIR/patches/$patch_name"
  target_dir="$ROM_ROOT/$repo_path"

  if [ ! -f "$patch_file" ] || [ ! -s "$patch_file" ]; then
    continue
  fi
  if [ ! -d "$target_dir" ]; then
    echo "[WARN] Skipping missing repo dir: $repo_path"
    continue
  fi

  if git -C "$target_dir" apply --check "$patch_file" >/dev/null 2>&1; then
    git -C "$target_dir" apply --whitespace=nowarn "$patch_file"
    echo "[OK] Applied $patch_name -> $repo_path"
  else
    echo "[WARN] Patch did not apply cleanly directly on HEAD for $repo_path (expected base $base_sha from $remote_url); check manually with: git -C $target_dir apply --reject $patch_file"
  fi
done < "$SCRIPT_DIR/BASE_SHAS.txt"

if [ -d "$SCRIPT_DIR/untracked" ]; then
  echo "==> Copying untracked AOSP overlay files..."
  cp -av "$SCRIPT_DIR/untracked/." "$ROM_ROOT/"
fi

echo "==> Done! Copy $SCRIPT_DIR/manifests/yogurt.xml to $ROM_ROOT/.repo/local_manifests/ before repo sync."

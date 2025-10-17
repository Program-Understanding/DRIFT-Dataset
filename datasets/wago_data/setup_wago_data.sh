#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Fixed config: always use stripped firmware-like binaries
# ============================================================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOADS="$BASE_DIR/downloads"
EXTRACTED="$BASE_DIR/extracted"
SAMPLES="$BASE_DIR/dropbear_samples"

mkdir -p "$DOWNLOADS" "$EXTRACTED"

# ---- URLs ----
declare -A FW_URLS=(
  ["03.10.10"]="https://github.com/WAGO/pfc-firmware/releases/download/v03.10.10-22/WAGO_FW0750-8x1x_V031010_IX22_SP1_r71749.img"
  ["03.10.08"]="https://github.com/WAGO/pfc-firmware/releases/download/v03.10.08-22/WAGO_FW0750-8x1x_V031008_IX22_r68457.img"
)

# ---- Replacement mapping (dest dir -> sample base name) ----
# (We'll resolve to stripped path "$SAMPLES/stripped/${base}.stripped")
declare -A REP_BASENAME=(
  ["03.10.08-clean"]="dropbear83-clean"
  ["03.10.10-clean"]="dropbear86-clean"
  ["03.10.10-backdoor"]="dropbear86-backdoor"
)

echo ">> mode: stripped (preserve sample filenames)"

# ---- Resolve a safe binwalk (prefer system over venv) ----
BINWALK_BIN=""
if [[ -x /usr/bin/binwalk ]]; then
  BINWALK_BIN="/usr/bin/binwalk"
else
  BINWALK_BIN="$(command -v binwalk || true)"
fi
if [[ -z "${BINWALK_BIN}" ]]; then
  echo "Missing command: binwalk"; exit 1
fi
if [[ "${BINWALK_BIN}" == *"/venv/"* ]]; then
  echo "Warning: Using venv binwalk at ${BINWALK_BIN}. If this fails, install system binwalk and rerun."
fi

# ---- Dependencies ----
for c in wget sha256sum strings find cp chmod ln rsync; do
  command -v "$c" >/dev/null 2>&1 || { echo "Missing command: $c"; exit 1; }
done
command -v unsquashfs >/dev/null 2>&1 || { echo "Missing command: unsquashfs (install squashfs-tools)"; exit 1; }

copy_tree() {
  mkdir -p "$2"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$1"/ "$2"/
  else
    cp -a "$1"/. "$2"/
  fi
}

# --- improved root finder (broader) ---
find_ext_root() {
  find "$1" -type d \
    \( -iname 'ext-root' -o -iname 'rootfs' -o -iname 'squashfs-root' \
       -o -iname '*rootfs*' -o -iname '*-root' -o -iname 'fs' \) \
    -print -quit
}

# --- canonical dropbear path ---
find_dropbear_candidates() {
  local root="$1"
  local path="$root/usr/sbin/dropbear"
  if [[ -f "$path" || -L "$path" ]]; then
    printf '%s\n' "$path"
    return 0
  else
    return 1
  fi
}

# Resolve sample path from REP_BASENAME (always stripped)
resolve_sample_path() {
  local map_key="$1"     # e.g., 03.10.10-backdoor
  local base="${REP_BASENAME[$map_key]:-}"
  if [[ -z "$base" ]]; then
    echo "ERROR: No replacement base name for key '$map_key'" >&2
    return 1
  fi
  echo "$SAMPLES/stripped/${base}.stripped"
}

# --- remove by dropbear hash & insert mapped replacement in usr/sbin/ ---
#     preserve original sample filename; symlink dropbear -> <sample_filename>
remove_dropbear_and_insert() {
  local src="$1"     # source rootfs copied tree
  local dst="$2"     # destination variant dir to create
  local map_key="$3" # key into REP_BASENAME, e.g., 03.10.10-backdoor

  echo "==> Creating $dst from $src ($map_key)"
  rm -rf "$dst"
  copy_tree "$src" "$dst"

  # Locate canonical dropbear (file or symlink)
  local cand
  if ! cand="$(find_dropbear_candidates "$dst")"; then
    echo "No 'usr/sbin/dropbear' found in $dst"
  else
    echo "   Found dropbear: $cand"

    # If it's a symlink, resolve the target for hashing/removal
    local real_cand="$cand"
    if [[ -L "$cand" ]]; then
      real_cand="$(readlink -f "$cand")" || true
      [[ -n "$real_cand" && -e "$real_cand" ]] || real_cand="$cand"
      echo "   Symlink resolves to: $real_cand"
    fi

    # compute sha of the exact file if it's a regular file
    if [[ -f "$real_cand" ]]; then
      local sha
      sha=$(sha256sum "$real_cand" | awk '{print $1}')
      echo "   SHA256(file) = $sha"

      # build hash map once
      local hashfile="$dst/.hashes"
      ( cd "$dst" && find . -type f -print0 | xargs -0 sha256sum ) > "$hashfile"

      # Remove all files matching that sha
      echo "   Removing all files matching hash: $sha"
      awk -v S="$sha" '$1==S {print $2}' "$hashfile" \
        | sed 's#^\./##' \
        | while read -r rel; do
            [[ -n "$rel" && -f "$dst/$rel" ]] && rm -f "$dst/$rel" 2>/dev/null || true
          done
    fi

    # Regardless, remove/replace the dropbear path itself (file or symlink)
    rm -f "$cand" || true
  fi

  # Insert mapped replacement in /usr/sbin/ using its original filename
  local rep
  if ! rep="$(resolve_sample_path "$map_key")"; then
    exit 1
  fi
  [[ -f "$rep" ]] || { echo "ERROR: Replacement binary not found: $rep"; exit 1; }

  local usr_sbin="$dst/usr/sbin"
  local sample_name
  sample_name="$(basename "$rep")"
  local placed="$usr_sbin/$sample_name"

  echo "==> Installing sample (preserve name):"
  echo "    $rep -> $placed"
  mkdir -p "$usr_sbin"
  cp -a "$rep" "$placed"
  chmod +x "$placed" || true

  # Create/refresh symlink: dropbear -> <sample_name>
  echo "==> Linking dropbear -> $sample_name"
  ln -sfn "$sample_name" "$usr_sbin/dropbear"

  echo "✅ Placed $sample_name and linked dropbear -> $sample_name"
}

# ============================================================
# Main
# ============================================================
for ver in 03.10.10 03.10.08; do
  url="${FW_URLS[$ver]}"
  img="$DOWNLOADS/$(basename "$url")"

  echo "==> [$ver] Downloading"
  wget -c -O "$img" "$url"

  echo "==> [$ver] Extracting with binwalk ($BINWALK_BIN)"
  (cd "$EXTRACTED" && "$BINWALK_BIN" -Me "$img")

  extracted_dir="$EXTRACTED/_$(basename "$img").extracted"
  root=$(find_ext_root "$extracted_dir")
  [[ -z "$root" ]] && { echo "No ext-root found for $ver"; exit 1; }

  copy_tree "$root" "$BASE_DIR/$ver"
done

# Build final variants per mapping table
remove_dropbear_and_insert "$BASE_DIR/03.10.10" "$BASE_DIR/03.10.10-backdoor" "03.10.10-backdoor"
remove_dropbear_and_insert "$BASE_DIR/03.10.10" "$BASE_DIR/03.10.10-clean"    "03.10.10-clean"
remove_dropbear_and_insert "$BASE_DIR/03.10.08" "$BASE_DIR/03.10.08-clean"    "03.10.08-clean"

FINAL_DIR="$BASE_DIR/experiment_samples"
mkdir -p "$FINAL_DIR"

echo
echo "==> Moving final sample directories into $FINAL_DIR"
for dir in "$BASE_DIR"/03.10.10-backdoor "$BASE_DIR"/03.10.10-clean "$BASE_DIR"/03.10.08-clean; do
  if [[ -d "$dir" ]]; then
    echo "   Moving $(basename "$dir")"
    mv "$dir" "$FINAL_DIR/"
  fi
done

echo "==> Removing intermediate folders (03.10.10, 03.10.08, downloads, extracted)"
rm -rf "$BASE_DIR"/03.10.10 "$BASE_DIR"/03.10.08 "$BASE_DIR"/downloads "$BASE_DIR"/extracted

echo
echo "✅ Cleanup complete"
echo "✅ Done. Generated datasets in:"
echo "  $FINAL_DIR/03.10.10-backdoor"
echo "  $FINAL_DIR/03.10.10-clean"
echo "  $FINAL_DIR/03.10.08-clean"

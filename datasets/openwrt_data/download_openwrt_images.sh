#!/bin/bash
set -euo pipefail

BASE_DIR="openwrt-images"

# Map of arch/version → download URL
declare -A URLS=(
  ["x86/22.03.1"]="https://mirror-03.infra.openwrt.org/releases/22.03.1/targets/x86/generic/openwrt-22.03.1-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.2"]="https://mirror-03.infra.openwrt.org/releases/22.03.2/targets/x86/generic/openwrt-22.03.2-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.3"]="https://mirror-03.infra.openwrt.org/releases/22.03.3/targets/x86/generic/openwrt-22.03.3-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.4"]="https://mirror-03.infra.openwrt.org/releases/22.03.4/targets/x86/generic/openwrt-22.03.4-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.5"]="https://mirror-03.infra.openwrt.org/releases/22.03.5/targets/x86/generic/openwrt-22.03.5-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.6"]="https://mirror-03.infra.openwrt.org/releases/22.03.6/targets/x86/generic/openwrt-22.03.6-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/22.03.7"]="https://mirror-03.infra.openwrt.org/releases/22.03.7/targets/x86/generic/openwrt-22.03.7-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.2"]="https://mirror-03.infra.openwrt.org/releases/23.05.2/targets/x86/generic/openwrt-23.05.2-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.3"]="https://mirror-03.infra.openwrt.org/releases/23.05.3/targets/x86/generic/openwrt-23.05.3-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.4"]="https://mirror-03.infra.openwrt.org/releases/23.05.4/targets/x86/generic/openwrt-23.05.4-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/23.05.5"]="https://mirror-03.infra.openwrt.org/releases/23.05.5/targets/x86/generic/openwrt-23.05.5-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/24.10.0"]="https://mirror-03.infra.openwrt.org/releases/24.10.0/targets/x86/generic/openwrt-24.10.0-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/24.10.1"]="https://mirror-03.infra.openwrt.org/releases/24.10.1/targets/x86/generic/openwrt-24.10.1-x86-generic-generic-squashfs-rootfs.img.gz"
  ["x86/24.10.2"]="https://mirror-03.infra.openwrt.org/releases/24.10.2/targets/x86/generic/openwrt-24.10.2-x86-generic-generic-squashfs-rootfs.img.gz"
)


mkdir -p "$BASE_DIR"

for key in $(printf '%s\n' "${!URLS[@]}" | sort); do
  arch="${key%%/*}"
  version="${key##*/}"
  name="${version}-${arch}"

  url="${URLS[$key]}"
  gz_path="$BASE_DIR/${name}.img.gz"
  img_path="${gz_path%.gz}"

  echo "📥 Downloading ${name}.img.gz"
  curl -L -o "$gz_path" "$url"

  echo "📦 Decompressing ${name}.img.gz"
  gunzip -f "$gz_path"

  echo "📂 Unpacking SquashFS into $BASE_DIR/${name}"
  unsquashfs -d "$BASE_DIR/${name}" "$img_path" \
    || echo "⚠️ Warning: non-zero exit (likely /dev files)"

  echo "🧹 Removing raw image ${name}.img"
  rm -f "$img_path"

  echo "✅ Done: $name"
done

echo "🎉 All images are in $BASE_DIR, each extracted under its own <version>-<arch> folder."

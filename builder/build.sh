#!/usr/bin/env bash
set -euo pipefail

OPENWRT_TAG="v25.12.5"
MODEM_FEED_COMMIT="f24a7deea1e627e5a1f176ca8d6c47b6f4bf4a56"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/.work}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/output}"
JOBS="${JOBS:-$(nproc)}"

rm -rf "$WORK_DIR/openwrt" "$OUT_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

git clone --depth 1 --branch "$OPENWRT_TAG" https://github.com/openwrt/openwrt.git "$WORK_DIR/openwrt"
cd "$WORK_DIR/openwrt"

cp feeds.conf.default feeds.conf
printf '\nsrc-git modem https://github.com/fildunsky/luci-app-5gmodem.git^%s\n' "$MODEM_FEED_COMMIT" >> feeds.conf

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -f luci-app-5gmodem

# MCR-202 keeps the stock FriendlyARM NanoPi NEO target, but changes three
# hardware-specific pieces: four-port LAN defaults, the U-Boot modem-power
# sequence, and a DT gpio-hog that keeps PE12/GPIO140 high after Linux starts.
python3 - <<'PY'
from pathlib import Path

# 4x LAN: onboard eth0 + three LAN9514 USB Ethernet ports.
p = Path('target/linux/sunxi/base-files/etc/board.d/02_network')
s = p.read_text()
needle = '\tcase "$board" in\n\tfriendlyarm,nanopi-r1|\\\n'
replacement = ('\tcase "$board" in\n'
               '\tfriendlyarm,nanopi-neo)\n'
               '\t\tucidef_set_interface_lan "eth0 eth1 eth2 eth3"\n'
               '\t\t;;\n'
               '\tfriendlyarm,nanopi-r1|\\\n')
if needle not in s:
    raise SystemExit('Cannot patch sunxi 02_network: expected context not found')
p.write_text(s.replace(needle, replacement, 1))

# Use the MCR-202-specific U-Boot environment script for NanoPi NEO.
p = Path('package/boot/uboot-sunxi/Makefile')
s = p.read_text()
needle = ('define U-Boot/nanopi_neo\n'
          '  BUILD_SUBTARGET:=cortexa7\n'
          '  NAME:=U-Boot for NanoPi NEO (H3)\n'
          '  BUILD_DEVICES:=friendlyarm_nanopi-neo\n'
          'endef')
replacement = ('define U-Boot/nanopi_neo\n'
               '  BUILD_SUBTARGET:=cortexa7\n'
               '  NAME:=U-Boot for NanoPi NEO (H3)\n'
               '  BUILD_DEVICES:=friendlyarm_nanopi-neo\n'
               '  UENV:=mcr202\n'
               'endef')
if needle not in s:
    raise SystemExit('Cannot patch uboot-sunxi Makefile: expected context not found')
p.write_text(s.replace(needle, replacement, 1))
PY

install -m 0644 "$ROOT_DIR/builder/uEnv-mcr202.txt" \
    package/boot/uboot-sunxi/uEnv-mcr202.txt
install -m 0644 "$ROOT_DIR/builder/kernel/999-mcr202-modem-power.patch" \
    target/linux/sunxi/patches-6.12/999-mcr202-modem-power.patch

mkdir -p files
cp -a "$ROOT_DIR/builder/files/." files/
chmod 0755 \
    files/etc/init.d/mcr202-modems \
    files/etc/uci-defaults/99-mcr202-defaults \
    files/usr/bin/mcr202-qmi-map

cp "$ROOT_DIR/builder/config.seed" .config
make defconfig

# Fail early if the requested external LuCI package was not selected.
grep -q '^CONFIG_PACKAGE_luci-app-5gmodem=y$' .config || {
    echo 'ERROR: luci-app-5gmodem was not selected after make defconfig' >&2
    exit 1
}

make download -j"$JOBS"
make -j"$JOBS" || make -j1 V=s

TARGET_DIR="bin/targets/sunxi/cortexa7"
IMAGE="$(find "$TARGET_DIR" -maxdepth 1 -type f -name '*friendlyarm_nanopi-neo-squashfs-sdcard.img.gz' | head -n1)"
[ -n "$IMAGE" ] && [ -f "$IMAGE" ] || {
    echo 'ERROR: final NanoPi NEO sdcard image not found' >&2
    exit 1
}

OUT_IMAGE="$OUT_DIR/openwrt-25.12.5-biforcom-mcr202-squashfs-sdcard.img.gz"
cp "$IMAGE" "$OUT_IMAGE"
sha256sum "$OUT_IMAGE" | tee "$OUT_DIR/SHA256SUMS"
cp .config "$OUT_DIR/openwrt-25.12.5-mcr202.config"

printf '\nBuilt: %s\n' "$OUT_IMAGE"

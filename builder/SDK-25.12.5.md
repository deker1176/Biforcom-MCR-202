# Verified OpenWrt 25.12.5 SDK for MCR-202

The SDK supplied for this project was inspected before using it as the package-build reference.

## Archive

```text
openwrt-sdk-25.12.5-sunxi-cortexa7_gcc-14.3.0_musl_eabi.Linux-x86_64.tar.zst
```

SHA-256:

```text
a6721d2787893095db039c493b51729e9d80a2f440a9cd4d13e3b055dd128e3b
```

## Embedded OpenWrt metadata

```text
OpenWrt: 25.12.5
Revision: r33051-f5dae5ece4
Target: sunxi/cortexa7
Toolchain: GCC 14.3.0 + musl EABI
Kernel: 6.12.94
Architecture: arm_cortex-a7+neon-vfpv4
```

The SDK's `include/version.mk` reports the same OpenWrt 25.12.5 revision as the official release.

## MCR-202 related checks

- `CONFIG_GPIO_SYSFS=y` in the SDK kernel configuration, therefore the existing GPIO141 startup method remains usable.
- `target/linux/generic/hack-6.12/780-usb-net-MeigLink_modem_support.patch` is present and includes MeigLink SLM750 (`05c6:f601`) support for `qmi_wwan` and `option`.
- Kernel package definitions are present for:
  - `kmod-usb-serial-option`
  - `kmod-usb-serial-qualcomm`
  - `kmod-usb-net-qmi-wwan`
  - `kmod-usb-net-cdc-mbim`
  - `kmod-usb-net-rndis`
  - `kmod-usb-acm`
- Quectel EC25 and EC200A are supported by the Linux 6.12 USB serial/QMI stack used by OpenWrt 25.12.5; no separate vendor kernel module is planned.

The SDK is used as a compatibility/package reference. The complete MCR-202 firmware is built from the full OpenWrt `v25.12.5` source tree because the project also changes the DT, U-Boot environment and board defaults.

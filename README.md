# 🚀 Android LUKS Mounter ✨

Professional storage management for **LUKS-encrypted** and **plain** drives on Android. This project brings desktop-class security and advanced mounting features to your mobile device.

Authored with ❤️ by **Rex Ackermann**.

<!-- INSTALL_START -->
<table><tr><td valign="top" width="65%">

### Install (root shell one-liner)

The **online ZIP** downloads dependencies at flash time (needs network).

<details open>
<summary><b>KernelSU</b></summary>

```sh
curl -Lo /tmp/mounter.zip https://github.com/rexackermann/android-luks-mounter/releases/latest/download/android-luks-mounter-v1.5.62.zip && /data/adb/ksud module install /tmp/mounter.zip
```
</details>

<details>
<summary><b>APatch</b></summary>

```sh
curl -Lo /tmp/mounter.zip https://github.com/rexackermann/android-luks-mounter/releases/latest/download/android-luks-mounter-v1.5.62.zip && apd module install /tmp/mounter.zip
```
</details>

<details>
<summary><b>Magisk</b></summary>

```sh
curl -Lo /tmp/mounter.zip https://github.com/rexackermann/android-luks-mounter/releases/latest/download/android-luks-mounter-v1.5.62.zip && magisk --install-module /tmp/mounter.zip
```
</details>

</td><td valign="top" align="right" width="35%">

<p align="right">
<img src="https://img.shields.io/badge/version-v1.5.62-7c3aed?style=for-the-badge&logo=github&logoColor=white"><br>
<img src="https://img.shields.io/badge/versionCode-1562-2563eb?style=for-the-badge"><br>
<img src="https://img.shields.io/badge/arm64%20%2B%20arm-supported-0891b2?style=for-the-badge"><br>
<img src="https://img.shields.io/badge/Termux-required-ef4444?style=for-the-badge">
</p>

</td></tr></table>

<!-- INSTALL_END -->

---

## 🌟 Key Features

- **🔓 LUKS Support** — Unlock and mount encrypted removable storage.
- **📁 Filesystem Support** — NTFS, exFAT, VFAT, F2FS, ext filesystems, and more where supported by the device.
- **⚡ Auto-Mounting** — Detects OTG and SD-card devices on plug-in and cleans them up on unplug.
- **🤖 Event-Driven Daemon** — Uses inotify with a 60-second health-check fallback.
- **🛡️ Safety Checks** — Rejects internal, loop, and device-mapper devices and verifies mounts after creation.
- **🌐 Built-in WebUI** — Manage devices, keys, configuration, and logs without a separate server.

## 🌐 WebUI

Open the module's **WebUI** entry in KernelSU, APatch, or ReSukiSU. The bridge supports KernelSU object responses, ReSukiSU strings, and APatch/MMRL response objects.

## 🛠️ Requirements

- Rooted Android: KernelSU, APatch, ReSukiSU, or Magisk
- Termux from [F-Droid](https://f-droid.org/packages/com.termux/), not the Play Store build
- Required tools: `cryptsetup`, `bindfs`, `blkid`, `nsenter`, `mount`, and `umount`
- Recommended: `inotify-tools`
- Optional: `ntfs-3g`

```sh
pkg update && pkg upgrade
pkg install root-repo
pkg install cryptsetup bindfs inotify-tools
# Optional NTFS fallback:
pkg install ntfs-3g
```

## 📖 Usage

```sh
mounter --status
mounter /dev/block/sda1 MyDrive
mounter --unmount MyDrive
mounter --scan
mounter --all
```

Automatic discovery handles `/dev/block/sd*` and `/dev/block/mmcblk1*`. Internal `mmcblk0*`, `dm-*`, and `loop*` devices are excluded deliberately.

## ⚙️ Configuration

Configuration is a trusted shell fragment at:

```text
/storage/emulated/0/Documents/luks_keys/config
```

The default Android-visible path is `/storage/emulated/0/ext`. Per-device mappings use the LUKS UUID with hyphens replaced by underscores:

```sh
BASE_STORAGE_PATH="/storage/emulated/0/ext"
MAPPING_11111111_2222_3333_4444_555555555555="MyDrive"
STORAGE_PATH_11111111_2222_3333_4444_555555555555="/storage/emulated/0/ext/MyDrive"
# KEY_PATH_11111111_2222_3333_4444_555555555555="/path/to/keyfile"
```

Keyfiles are stored by default in `/storage/emulated/0/Documents/luks_keys/`. Automatic unlock requires a keyfile that is already enrolled in the LUKS device.

## ❓ Troubleshooting

```sh
su -c '/system/bin/mounter --status'
su -c 'tail -200 /data/local/tmp/mounter.log'
su -c 'ls -l /data/local/tmp/mounter_failures'
```

When reporting a problem, include your Android version, ROM, root manager, device node, filesystem type, status output, and relevant logs. Never include passphrases or key material.

## 🔨 Building

```sh
git clone https://github.com/rexackermann/android-luks-mounter.git
cd android-luks-mounter
bash build.sh
```

## ⚖️ License

Released under the [MIT License](LICENSE).

<div align="center">

Created and maintained by [Rex Ackermann](https://github.com/rexackermann)

</div>

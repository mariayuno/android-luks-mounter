# 🚀 Android LUKS Mounter ✨

Professional storage management for **LUKS-encrypted** and **plain** drives on Android. This project brings desktop-class security and advanced mounting features to your mobile device, supporting hotplugging, auto-unlocking, and seamless app integration.

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

## 👤 Author Information
- **Author**: Rex Ackermann
- **GitHub**: [@rexackermann](https://github.com/rexackermann) 🌐

---

## 🌟 Key Features
- **🔓 LUKS Support**: Real-time unlocking and mounting of encrypted volumes.
- **📁 Filesystem Versatility**: Supports NTFS, ExFAT, BTRFS, F2FS, VFAT, and more.
- **⚡ Auto-Mounting**: Automatically detects and mounts connected OTG and SD cards on plug-in, cleans up on unplug.
- **🤖 Event-Driven Daemon**: inotify-based service reacts instantly to block device events with coalesced triggering; falls back to a 60 s health-check poll when `inotify-tools` is unavailable.
- **🪄 Dynamic Skeleton**: Automatically "blesses" mount points at boot for perfect permissions.
- **🛡️ Safety Checks**: Intelligent protection against accidental mounting of system partitions.
- **📦 Flashable Module**: One-click installation for KernelSU, APatch, ReSukiSU, and Magisk.
- **🌐 Built-in WebUI**: Full browser-based management interface, no extra apps needed.

---

## 🌐 WebUI (KernelSU / APatch / ReSukiSU)

A built-in web interface is available directly from your SU Manager. No extra apps needed.

### Features
- **📊 Dashboard** — Live device table with encryption state, mount points, bindfs paths, and per-device actions
- **💾 Devices** — Manual mount/unmount by path or label, blocked device manager
- **🔑 Keys** — Browse, generate, and delete LUKS keyfiles
- **⚙️ Config** — Edit `mounter config` in-browser, install boot service, link binary
- **📋 Logs** — Live log viewer with colour-coded output, one-tap clear
- **🔐 Unlock** — Passphrase prompt for locked LUKS devices directly from the UI

### How to open
1. Open **KernelSU**, **APatch**, or **ReSukiSU**
2. Find **Android LUKS Mounter** in the modules list
3. Tap the **WebUI** button

> The WebUI communicates with the `mounter` binary directly via the shell bridge — no extra server required.

### Compatibility
The WebUI bridge layer is compatible with all major KernelSU-based managers:

| Manager | Bridge API | Status |
|---------|-----------|--------|
| KernelSU | `{stdout, stderr, errno}` | ✅ |
| ReSukiSU | plain string return | ✅ |
| APatch | `{out, err, code}` | ✅ |
| MMRL | `{out, err, code}` | ✅ |

---

## 🛠️ Prerequisites & Requirements

1. **🔑 Root Access**: KernelSU, APatch, ReSukiSU, or Magisk.

2. **📦 Dependencies** — install via Termux:
   ```sh
   pkg install cryptsetup bindfs inotify-tools
   ```
   `ntfs-3g` is optional (NTFS write support):
   ```sh
   pkg install ntfs-3g
   ```
---

## 🚀 Installation

### Option 1: Flashable Module (Recommended)
1. Download the latest `android-luks-mounter-vX.X.X.zip` from the [Releases](https://github.com/rexackermann/android-luks-mounter/releases).
2. Flash it in your SU Manager (KernelSU, APatch, ReSukiSU, or Magisk).
3. **Reboot**. This is required for the Dynamic Skeleton to initialize.

---

## 📖 How to Use

### 📁 Automatic Mode (Plug & Play)
Once installed and rebooted, simply plug in your drive. The background service will:
1. Detect the drive instantly via inotify on `/dev/block` (requires `inotify-tools` installed in Termux), or within 60 s via the health-check poll if unavailable.
2. Auto-unlock it if a key exists in `/data/adb/mounter/`.
3. Mount it to your configured path (default: `/sdcard/ext/label`).
4. Clean up bindfs views and LUKS mappers automatically on unplug.

### 🌐 WebUI Mode
Open your SU Manager, find the module, and tap **WebUI**. From there you can mount, unmount, unlock LUKS volumes, manage keyfiles, edit config, and tail logs — all without touching a terminal.

### ⌨️ CLI Mode
Open Termux and run:
- `mounter --status` : See current mount status and connected drives.
- `mounter /dev/block/sda1 MyDrive` : Mount a specific device manually.
- `mounter -u MyDrive` : Safely unmount a drive by its label.

---

## ⚙️ Configuration
Your settings live at `/data/adb/mounter/config`.

### **Custom Mount Points**
You can change where a drive appears by editing the `STORAGE_PATH` for its UUID:
```bash
STORAGE_PATH_abc_123="/storage/emulated/0/MyCustomFolder"
```
> [!TIP]
> After changing a path in the config, **REBOOT ONCE**. The "Dynamic Skeleton" logic will detect the new path and ensure it has the correct permissions for Android apps to write to it.

---

## ❓ FAQ & Troubleshooting

### **Q: My file manager says the drive is Read-Only!**
**A:** This is usually because the "Magic Mount" trick didn't run.
1. Ensure you have **rebooted** at least once after installation.
2. Check if your path is inside your internal storage (e.g., `/sdcard/something`).
3. Check the logs: `cat /data/local/tmp/mounter.log`.

### **Q: Why are my folders owned by `root` or `media_rw`?**
**A:** This is intentional! Android's security layer blocks write access to files owned by regular users in shared storage. By using the `media_rw` (1023) group and the "Magic Mount" trick, we bypass these restrictions so that **all** apps can read and write to your drive.

### **Q: How do I add an auto-unlock key?**
**A:** Mount the drive once using a password. The script will ask if you want to generate a keyfile. If you say `y`, it will create a secure key in `/data/adb/mounter/` for future use.

### **Q: The WebUI loads but nothing works / all panels are empty.**
**A:** This can happen on some KernelSU forks (e.g. older ReSukiSU builds) where `ksu.exec()` returns a plain string instead of an object. Make sure you are on **v1.5.41 or later** which normalises the bridge response automatically. If you are already on a recent version, open the WebView console and run:
```js
(async()=>{ console.log(typeof await window.ksu.exec('id')) })()
```
It should log `string` or `object`. Either is handled. If `window.ksu` is `undefined`, the WebUI was not opened via the SU Manager's WebUI button.

---

## ⚖️ License
Released under the **MIT License**. See `LICENSE` for details.

---

*Created with ❤️ by [Rex Ackermann](https://github.com/rexackermann)*

---

## 👥 Contributors

| Contributor | Role |
|-------------|------|
| [Rex Ackermann](https://github.com/rexackermann) | Author & maintainer |
| [mariayuno](https://github.com/mariayuno) | WebUI, bridge compatibility (ReSukiSU / APatch / MMRL) |


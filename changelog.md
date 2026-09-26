# Changelog

## v1.5.39 — 2026-09-26
### ci: GitHub Actions auto-build & release (PR #3)
- **⚙️ Auto-build on every commit**: every push to `main` triggers a full build and GitHub Release
- **🔢 Auto version bump**: patch version incremented automatically on each commit, written back to `module.prop` and `update.json`
- **📦 Artifact upload**: flashable ZIP uploaded as artifact on every run (PRs included, 30-day retention)
- **🚀 Automatic releases**: GitHub Release created with ZIP attached on every `main` push — no manual tagging needed
- **Contributor**: [@mariayuno](https://github.com/mariayuno)

## v1.5.38 — 2026-09-26
### feat: KernelSU / APatch WebUI (PR #2)
- **🌐 Built-in WebUI**: single-file browser interface served natively by KernelSU/APatch WebView — no extra server or app required
- **📊 Dashboard**: live device table with encryption state, mount points, bindfs user paths, and per-device Mount / Unmount / Unlock actions
- **💾 Devices page**: manual mount by path or label, blocked device manager with per-device unblock
- **🔑 Keys page**: browse keyfiles, generate new 512-byte urandom keys, delete keys
- **⚙️ Config page**: full in-browser editor for `mounter config`, install boot service button, link binary button
- **📋 Logs page**: live tail of `mounter.log` with colour-coded output (info/warn/error/ok), one-tap clear
- **🔐 Unlock modal**: passphrase prompt for locked LUKS devices, delegates directly to `mounter` binary via `ksu.exec()` bridge
- **📱 Responsive**: works on phone screen (bottom tab bar on narrow viewports)
- `customize.sh`: one line added — `set_perm_recursive` for `webroot/`
- `README.md`: WebUI section and contributors table added
- **Contributor**: [@mariayuno](https://github.com/mariayuno)

## v1.5.0-OPTIMIZED
- **🏗️ Repository Restructure**: Flattened the repo to eliminate file duplication; the repository root is now the Magisk module source.
- **🔑 Custom Key Mapping**: Support for `KEY_PATH_${safe_uuid}` in the config to link specific keyfiles (including those without `.key` extension).
- **🚀 Discovery Optimization**: Improved the automatic key lookup to gracefully handle non-standard filenames like 'al'.
- **🛠️ Build Refresh**: Updated `build.sh` to correctly package the new root-based structure.

## v1.4.3-ULTIMATE
- Fixed nsenter argument parsing with absolute paths and flag separation.
- Implemented a Binary Registry log for deterministic tool discovery.
- Enhanced Su Manager compatibility (KernelSU/Suki) with version code bumping.
- Fixed FBE unlock detection for reliable boot mounting.

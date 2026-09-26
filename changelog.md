# Changelog

## v1.5.50 — 2026-09-27
### fix: event-driven service + sed fix + coalesced triggering (PR #12)
- **🐛 Remount loop fixed**: `sed -E 's|^(/storage/emulated/0|/sdcard)|...|'` had an unescaped `|` in the alternation, causing Android's `sed` to error on every poll iteration — `_real_storage_chk` was always empty, the user-view check never passed, and bindfs was recreated every 10 s indefinitely. Fixed by escaping the pipe: `\|`
- **⚡ Event-driven service**: replaced the 10 s blind poll loop with `inotifywait` watching `/dev/block` (not `/sys/block` — inotify does not fire on sysfs on Android kernels) for `CREATE` and `DELETE` events, filtered to `sd[a-z]*` and `mmcblk1*`
- **🔒 Coalesced triggering**: a plug-in event fires multiple nodes (`sda` + `sda1`, `mmcblk1` + `mmcblk1p1`) simultaneously — added a two-slot gate (one running + one pending) so concurrent triggers are coalesced into at most two sequential runs; all further triggers are dropped until the queue drains. Prevents a storm of 100 events from queuing 100 mounter runs
- **🔌 Unplug cleanup**: `DELETE` events now trigger `mounter --all` immediately, which calls `cleanup_stale_mounts()` to tear down orphaned bindfs views and LUKS mappers — previously unplug was only caught by the health-check poll up to 60 s later
- **⏱️ Health-check poll**: kept at 60 s alongside the event listener to catch silent bindfs failures that events cannot observe
- **📦 Explicit Termux path**: `inotifywait` referenced by absolute path (`/data/data/com.termux/files/usr/bin/inotifywait`) — `command -v` is unreliable before Termux PATH is injected by the mounter binary
- **Contributor**: [@mariayuno](https://github.com/mariayuno)

## v1.5.45 — 2026-09-26
### chore: version bump [auto]
- CI auto-bump following PR #10 merge

## v1.5.44 — 2026-09-26
### chore: version bump [auto]
- CI auto-bump

## v1.5.43 — 2026-09-26
### chore: version bump [auto]
- CI auto-bump

## v1.5.42 — 2026-09-26
### chore: version bump [auto]
- CI auto-bump

## v1.5.41 — 2026-09-26
### chore: version bump [auto]
- CI auto-bump following WebUI merge

## v1.5.40 — 2026-09-26
### fix: WebUI bridge compatibility with ReSukiSU and other KernelSU forks (PR #10)
- **🐛 WebUI now works on ReSukiSU**: some KernelSU forks return a plain `string` from `ksu.exec()` instead of the standard `{stdout, stderr, errno}` object — destructuring `{ stdout }` from a string always yields `undefined`, so every command silently received no output despite executing successfully as root
- **🔧 Normalised exec return value**: `sh()` now checks `typeof r === 'string'` before destructuring, wrapping plain-string returns as `{ stdout: r, stderr: '', errno: 0 }` so all existing callers work without changes
- **🔀 Field name fallback**: also normalises alternate field names (`out`/`err`/`code`) used by some APatch and MMRL builds
- **Contributor**: [@mariayuno](https://github.com/mariayuno)

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

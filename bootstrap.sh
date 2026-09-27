#!/system/bin/sh
# 📦 Android LUKS Mounter — Dependency Bootstrap
# Downloads required binaries from the Termux apt repo and installs them
# to /data/adb/mounter/bin/ and /data/adb/mounter/lib/.
# No apt, no GPG, no key expiry — raw .deb download and extraction only.
#
# Supports: aarch64 (arm64) and armv7 (arm 32-bit).
#
# Usage:
#   bootstrap.sh                  — normal mode, uses network
#   bootstrap.sh --offline <dir>  — offline mode, reads pre-downloaded .deb files from <dir>
#   bootstrap.sh --no-termux      — after bootstrap, write flag to ignore Termux at runtime

MOUNTER_BIN="/data/adb/mounter/bin"
MOUNTER_LIB="/data/adb/mounter/lib"
TERMUX_REPO="https://packages.termux.dev/apt/termux-main"
TMPDIR_BOOTSTRAP="/data/local/tmp/mounter_bootstrap"
LOG="/data/local/tmp/mounter.log"
NO_TERMUX_FLAG="/data/adb/mounter/.no_termux"

# Packages to fetch. ntfs-3g is optional — failure is warned, not fatal.
REQUIRED_PKGS="cryptsetup bindfs inotify-tools"
OPTIONAL_PKGS="ntfs-3g"

# --- Arg parsing ---
OFFLINE_DIR=""
NO_TERMUX=0
while [ $# -gt 0 ]; do
    case "$1" in
        --offline) OFFLINE_DIR="$2"; shift 2 ;;
        --no-termux) NO_TERMUX=1; shift ;;
        *) shift ;;
    esac
done

# --- Arch detection ---
DEVICE_ARCH=$(uname -m 2>/dev/null)
case "$DEVICE_ARCH" in
    aarch64|arm64) TERMUX_ARCH="aarch64" ;;
    armv7*|armv8l|arm) TERMUX_ARCH="arm" ;;
    *)
        echo "[bootstrap] ❌ Unsupported arch: $DEVICE_ARCH" | tee -a "$LOG"
        exit 1
        ;;
esac
echo "[bootstrap] 📱 Arch: $DEVICE_ARCH → Termux arch: $TERMUX_ARCH" | tee -a "$LOG"

# --- Tool check ---
BUSYBOX=""
for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox $(which busybox 2>/dev/null); do
    [ -x "$bb" ] && BUSYBOX="$bb" && break
done
[ -z "$BUSYBOX" ] && echo "[bootstrap] ❌ busybox not found." | tee -a "$LOG" && exit 1

if [ -z "$OFFLINE_DIR" ]; then
    WGET=""
    for dl in $(which wget 2>/dev/null) $(which curl 2>/dev/null) \
               /data/data/com.termux/files/usr/bin/wget \
               /data/data/com.termux/files/usr/bin/curl; do
        [ -x "$dl" ] && WGET="$dl" && break
    done
    [ -z "$WGET" ] && echo "[bootstrap] ❌ No download tool found." | tee -a "$LOG" && exit 1
fi

download() {
    local url="$1" dest="$2"
    case "$(basename "$WGET")" in
        wget) "$WGET" -q -O "$dest" "$url" ;;
        curl) "$WGET" -fsSL -o "$dest" "$url" ;;
    esac
}

# --- Setup dirs ---
mkdir -p "$MOUNTER_BIN" "$MOUNTER_LIB" "$TMPDIR_BOOTSTRAP"
chmod 700 "$MOUNTER_BIN" "$MOUNTER_LIB"

# --- Package index (online mode only) ---
PACKAGES_FILE="$TMPDIR_BOOTSTRAP/Packages"
if [ -z "$OFFLINE_DIR" ]; then
    echo "[bootstrap] 🌐 Fetching package index for $TERMUX_ARCH..." | tee -a "$LOG"
    PACKAGES_URL="$TERMUX_REPO/dists/stable/main/binary-$TERMUX_ARCH/Packages"
    if ! download "$PACKAGES_URL" "$PACKAGES_FILE"; then
        download "${PACKAGES_URL}.xz" "${PACKAGES_FILE}.xz" && \
            "$BUSYBOX" xz -d "${PACKAGES_FILE}.xz" || {
            echo "[bootstrap] ❌ Could not fetch package index." | tee -a "$LOG"
            exit 1
        }
    fi
fi

resolve_deb() {
    local pkg="$1"
    "$BUSYBOX" awk -v pkg="$pkg" '
        /^$/ {
            if (match_pkg && filename != "") { print filename; exit }
            match_pkg=0; filename=""
        }
        /^Package: / { match_pkg = ($2 == pkg) }
        /^Filename: / { filename = $2 }
        END { if (match_pkg && filename != "") print filename }
    ' "$PACKAGES_FILE"
}

extract_deb() {
    local deb="$1" workdir="$2"
    mkdir -p "$workdir"

    # ar extraction — try flags in order of busybox version compatibility
    "$BUSYBOX" ar x "$deb" --output="$workdir" 2>/dev/null || \
        "$BUSYBOX" ar x "$deb" -C "$workdir" 2>/dev/null || \
        ( cd "$workdir" && "$BUSYBOX" ar x "$deb" )

    local data_tar
    data_tar=$(ls "$workdir"/data.tar.* 2>/dev/null | head -1)
    [ -z "$data_tar" ] && return 1

    mkdir -p "$workdir/data"
    "$BUSYBOX" tar -xf "$data_tar" -C "$workdir/data" 2>/dev/null || return 1

    # Termux debs extract to ./data/data/com.termux/files/usr/{bin,lib}
    local base="$workdir/data/data/com.termux/files/usr"
    [ -d "$base/bin" ] && cp -f "$base/bin"/* "$MOUNTER_BIN/" 2>/dev/null
    [ -d "$base/lib" ] && cp -rf "$base/lib"/* "$MOUNTER_LIB/" 2>/dev/null
    chmod 755 "$MOUNTER_BIN"/* 2>/dev/null
    return 0
}

install_pkg() {
    local pkg="$1" optional="$2"
    echo "[bootstrap] 📥 Installing $pkg..." | tee -a "$LOG"

    local deb_file work
    deb_file="$TMPDIR_BOOTSTRAP/${pkg}.deb"
    work="$TMPDIR_BOOTSTRAP/${pkg}_work"

    if [ -n "$OFFLINE_DIR" ]; then
        # Offline: find pre-downloaded deb matching package name
        local found
        found=$(ls "$OFFLINE_DIR"/${pkg}_*.deb "$OFFLINE_DIR"/${pkg}-*.deb 2>/dev/null | head -1)
        if [ -z "$found" ]; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Offline: no .deb found for $pkg in $OFFLINE_DIR" | tee -a "$LOG"
            return 1
        fi
        cp "$found" "$deb_file"
    else
        local rel_path
        rel_path=$(resolve_deb "$pkg")
        if [ -z "$rel_path" ]; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Package '$pkg' not in index." | tee -a "$LOG"
            return 1
        fi
        if ! download "$TERMUX_REPO/$rel_path" "$deb_file"; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Download failed: $pkg" | tee -a "$LOG"
            return 1
        fi
    fi

    if ! extract_deb "$deb_file" "$work"; then
        echo "[bootstrap] ❌ Extraction failed: $pkg" | tee -a "$LOG"
        return 1
    fi

    echo "[bootstrap] ✅ $pkg installed." | tee -a "$LOG"
    rm -rf "$work" "$deb_file"
}

# --- Main ---
FAILED=""
for pkg in $REQUIRED_PKGS; do
    install_pkg "$pkg" || FAILED="$FAILED $pkg"
done
for pkg in $OPTIONAL_PKGS; do
    install_pkg "$pkg" optional || \
        echo "[bootstrap] ⚠️  $pkg skipped — NTFS write support unavailable." | tee -a "$LOG"
done

rm -rf "$TMPDIR_BOOTSTRAP"

if [ -n "$FAILED" ]; then
    echo "[bootstrap] ❌ Required packages failed:$FAILED" | tee -a "$LOG"
    exit 1
fi

# Write no-termux flag if requested
if [ "$NO_TERMUX" -eq 1 ]; then
    touch "$NO_TERMUX_FLAG"
    echo "[bootstrap] 🚫 Termux ignored at runtime (.no_termux flag set)." | tee -a "$LOG"
fi

echo "[bootstrap] 🎊 Bootstrap complete. Binaries at $MOUNTER_BIN" | tee -a "$LOG"
exit 0

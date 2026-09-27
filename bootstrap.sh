#!/system/bin/sh
# 📦 Android LUKS Mounter — Dependency Bootstrap
# Downloads required binaries from the Termux apt repo and installs them
# to /data/adb/mounter/bin/ and /data/adb/mounter/lib/.
# No apt, no GPG, no key expiry — raw .deb download and extraction only.
# Supports: aarch64 (arm64) and arm (32-bit).
#
# Usage:
#   bootstrap.sh                  — network mode
#   bootstrap.sh --offline <dir>  — use pre-downloaded .deb files from <dir>
#   bootstrap.sh --no-termux      — write .no_termux flag after bootstrap

MOUNTER_BIN="/data/adb/mounter/bin"
MOUNTER_LIB="/data/adb/mounter/lib"
TERMUX_REPO_MAIN="https://packages.termux.dev/apt/termux-main"
TERMUX_REPO_ROOT="https://packages.termux.dev/apt/termux-root"
TMPDIR_BOOTSTRAP="/data/local/tmp/mounter_bootstrap"
LOG="/data/local/tmp/mounter.log"
NO_TERMUX_FLAG="/data/adb/mounter/.no_termux"

# termux-exec provides libtermux-exec.so needed by all Termux-built binaries
REQUIRED_PKGS="termux-exec cryptsetup bindfs inotify-tools"
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
echo "[bootstrap] 📱 Arch: $DEVICE_ARCH → Termux repo: $TERMUX_ARCH" | tee -a "$LOG"

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

# --- Package index (online only) ---
# termux-exec + inotify-tools are in termux-main
# cryptsetup + bindfs + ntfs-3g are in termux-root
PACKAGES_FILE="$TMPDIR_BOOTSTRAP/Packages"
PACKAGES_MAIN="$TMPDIR_BOOTSTRAP/Packages.main"
PACKAGES_ROOT="$TMPDIR_BOOTSTRAP/Packages.root"
if [ -z "$OFFLINE_DIR" ]; then
    echo "[bootstrap] 🌐 Fetching package indexes ($TERMUX_ARCH)..." | tee -a "$LOG"

    fetch_index() {
        local url_base="$1" out="$2"
        # Try plain first (xz pipe is unreliable on some Android busybox builds)
        download "$url_base/Packages" "$out" && return 0
        download "$url_base/Packages.xz" "${out}.xz" && \
            "$BUSYBOX" xz -d "${out}.xz" && return 0
        return 1
    }

    MAIN_URL="$TERMUX_REPO_MAIN/dists/stable/main/binary-$TERMUX_ARCH"
    ROOT_URL="$TERMUX_REPO_ROOT/dists/root/main/binary-$TERMUX_ARCH"

    fetch_index "$MAIN_URL" "$PACKAGES_MAIN" || {
        echo "[bootstrap] ❌ Could not fetch termux-main index." | tee -a "$LOG"; exit 1
    }
    fetch_index "$ROOT_URL" "$PACKAGES_ROOT" || {
        echo "[bootstrap] ⚠️  Could not fetch termux-root index (cryptsetup/bindfs may fail)." | tee -a "$LOG"
        touch "$PACKAGES_ROOT"
    }

    cat "$PACKAGES_MAIN" "$PACKAGES_ROOT" > "$PACKAGES_FILE"
    echo "[bootstrap] 📦 Index: $(grep -c "^Package:" "$PACKAGES_FILE") packages" | tee -a "$LOG"
fi

resolve_deb() {
    local pkg="$1" fname
    # Search main first, then root — return "repo_url|filename"
    fname=$("$BUSYBOX" awk -v pkg="$pkg" '
        /^$/ { if (m && f) { print f; exit } m=0; f="" }
        /^Package: / { m=($2==pkg) }
        /^Filename: / { f=$2 }
        END { if (m && f) print f }
    ' "$PACKAGES_MAIN" 2>/dev/null)
    if [ -n "$fname" ]; then
        echo "${TERMUX_REPO_MAIN}|${fname}"; return 0
    fi
    fname=$("$BUSYBOX" awk -v pkg="$pkg" '
        /^$/ { if (m && f) { print f; exit } m=0; f="" }
        /^Package: / { m=($2==pkg) }
        /^Filename: / { f=$2 }
        END { if (m && f) print f }
    ' "$PACKAGES_ROOT" 2>/dev/null)
    if [ -n "$fname" ]; then
        echo "${TERMUX_REPO_ROOT}|${fname}"; return 0
    fi
    return 1
}

extract_deb() {
    local deb="$1" workdir="$2"
    mkdir -p "$workdir"
    "$BUSYBOX" ar x "$deb" --output="$workdir" 2>/dev/null || \
        "$BUSYBOX" ar x "$deb" -C "$workdir" 2>/dev/null || \
        ( cd "$workdir" && "$BUSYBOX" ar x "$deb" )
    local data_tar
    data_tar=$(ls "$workdir"/data.tar.* 2>/dev/null | head -1)
    [ -z "$data_tar" ] && return 1
    mkdir -p "$workdir/data"
    "$BUSYBOX" tar -xf "$data_tar" -C "$workdir/data" 2>/dev/null || return 1
    local base="$workdir/data/data/com.termux/files/usr"
    [ -d "$base/bin" ] && cp -f "$base/bin"/* "$MOUNTER_BIN/" 2>/dev/null
    [ -d "$base/lib" ] && cp -rf "$base/lib"/* "$MOUNTER_LIB/" 2>/dev/null
    chmod 755 "$MOUNTER_BIN"/* 2>/dev/null
    return 0
}

install_pkg() {
    local pkg="$1" optional="$2"
    echo "[bootstrap] 📥 Installing $pkg..." | tee -a "$LOG"
    local deb_file="$TMPDIR_BOOTSTRAP/${pkg}.deb"
    local work="$TMPDIR_BOOTSTRAP/${pkg}_work"

    if [ -n "$OFFLINE_DIR" ]; then
        # CI sanitizes colons in epoch versions (e.g. "1:2.5.0") to underscores.
        # Match both original and sanitized filenames.
        local found
        found=$(ls "$OFFLINE_DIR"/${pkg}_*.deb "$OFFLINE_DIR"/${pkg}-*.deb 2>/dev/null | head -1)
        if [ -z "$found" ]; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Offline: no .deb for $pkg in $OFFLINE_DIR" | tee -a "$LOG"
            return 1
        fi
        cp "$found" "$deb_file"
    else
        local resolved repo_url rel_path
        resolved=$(resolve_deb "$pkg")
        if [ -z "$resolved" ]; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} '$pkg' not in index." | tee -a "$LOG"
            return 1
        fi
        repo_url="${resolved%%|*}"
        rel_path="${resolved#*|}"
        if ! download "$repo_url/$rel_path" "$deb_file"; then
            echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Download failed: $pkg" | tee -a "$LOG"
            return 1
        fi
    fi

    if ! extract_deb "$deb_file" "$work"; then
        echo "[bootstrap] ❌ Extraction failed: $pkg" | tee -a "$LOG"
        return 1
    fi

    echo "[bootstrap] ✅ $pkg done." | tee -a "$LOG"
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

[ "$NO_TERMUX" -eq 1 ] && touch "$NO_TERMUX_FLAG" && \
    echo "[bootstrap] 🚫 Termux ignored at runtime (.no_termux set)." | tee -a "$LOG"

echo "[bootstrap] 🎊 Done. Binaries at $MOUNTER_BIN" | tee -a "$LOG"
exit 0

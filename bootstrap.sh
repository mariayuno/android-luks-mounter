#!/system/bin/sh
# 📦 Android LUKS Mounter — Dependency Bootstrap
# Downloads required binaries from the Termux apt repo and installs them
# to /data/adb/mounter/bin/ and /data/adb/mounter/lib/.
# No apt, no GPG, no key expiry — raw .deb download and extraction only.
#
# Supported arch: aarch64 (arm64) only.
# On 32-bit (armv7) devices this script exits 2 — caller falls back to Termux.

MOUNTER_BIN="/data/adb/mounter/bin"
MOUNTER_LIB="/data/adb/mounter/lib"
TERMUX_REPO="https://packages.termux.dev/apt/termux-main"
ARCH="aarch64"
TMPDIR_BOOTSTRAP="/data/local/tmp/mounter_bootstrap"
LOG="/data/local/tmp/mounter.log"

# Packages to fetch. ntfs-3g is optional — failure is warned, not fatal.
REQUIRED_PKGS="cryptsetup bindfs inotify-tools"
OPTIONAL_PKGS="ntfs-3g"

# --- Arch gate ---
DEVICE_ARCH=$(uname -m 2>/dev/null)
case "$DEVICE_ARCH" in
    aarch64|arm64) ;;
    *)
        echo "[bootstrap] ⚠️  Unsupported arch: $DEVICE_ARCH (arm64 only). Falling back to Termux." | tee -a "$LOG"
        exit 2
        ;;
esac

# --- Tool check ---
# We need busybox ar+tar+xz for .deb extraction and wget or curl for download.
# Magisk bundles busybox at /data/adb/magisk/busybox;
# KSU bundles it at /data/adb/ksu/bin/busybox.
BUSYBOX=""
for bb in /data/adb/magisk/busybox /data/adb/ksu/bin/busybox $(which busybox 2>/dev/null); do
    [ -x "$bb" ] && BUSYBOX="$bb" && break
done
if [ -z "$BUSYBOX" ]; then
    echo "[bootstrap] ❌ busybox not found — cannot extract .deb files." | tee -a "$LOG"
    exit 1
fi

WGET=""
for dl in $(which wget 2>/dev/null) $(which curl 2>/dev/null) \
           /data/data/com.termux/files/usr/bin/wget \
           /data/data/com.termux/files/usr/bin/curl; do
    [ -x "$dl" ] && WGET="$dl" && break
done
if [ -z "$WGET" ]; then
    echo "[bootstrap] ❌ No download tool (wget/curl) found." | tee -a "$LOG"
    exit 1
fi

# Wrap download: support both wget and curl transparently
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

# --- Fetch Packages index ---
echo "[bootstrap] 🌐 Fetching package index..." | tee -a "$LOG"
PACKAGES_URL="$TERMUX_REPO/dists/stable/main/binary-$ARCH/Packages"
PACKAGES_FILE="$TMPDIR_BOOTSTRAP/Packages"

# Try plain Packages first, fall back to Packages.xz
if ! download "$PACKAGES_URL" "$PACKAGES_FILE"; then
    download "${PACKAGES_URL}.xz" "${PACKAGES_FILE}.xz" && \
        "$BUSYBOX" xz -d "${PACKAGES_FILE}.xz" || {
        echo "[bootstrap] ❌ Could not fetch package index." | tee -a "$LOG"
        exit 1
    }
fi

# --- Helper: resolve .deb URL from Packages index ---
# Termux Packages format: blank-line separated stanzas.
# We find the stanza for $1 and extract its Filename: field.
resolve_deb() {
    local pkg="$1"
    # awk: collect stanza lines, on blank line check if Package: matched, print Filename:
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

# --- Helper: extract .deb into MOUNTER_BIN / MOUNTER_LIB ---
extract_deb() {
    local deb="$1" workdir="$2"
    mkdir -p "$workdir"

    # .deb is an 'ar' archive containing: debian-binary, control.tar.*, data.tar.*
    "$BUSYBOX" ar x "$deb" --output="$workdir" 2>/dev/null || \
        "$BUSYBOX" ar x "$deb" -C "$workdir" 2>/dev/null || {
        # Older busybox ar doesn't support -C / --output; cd instead
        ( cd "$workdir" && "$BUSYBOX" ar x "$deb" )
    }

    # Find the data tarball (may be .xz, .gz, or .zst)
    local data_tar
    data_tar=$(ls "$workdir"/data.tar.* 2>/dev/null | head -1)
    [ -z "$data_tar" ] && return 1

    # Extract into workdir/data/
    mkdir -p "$workdir/data"
    "$BUSYBOX" tar -xf "$data_tar" -C "$workdir/data" 2>/dev/null || return 1

    # Copy binaries — Termux paths inside tar are ./data/data/com.termux/files/usr/bin/
    local termux_bin="$workdir/data/data/data/com.termux/files/usr/bin"
    local termux_lib="$workdir/data/data/data/com.termux/files/usr/lib"
    # Some tarballs root at ./data/com.termux/... (no leading data/data/)
    [ -d "$workdir/data/data/com.termux/files/usr/bin" ] && \
        termux_bin="$workdir/data/data/com.termux/files/usr/bin"
    [ -d "$workdir/data/data/com.termux/files/usr/lib" ] && \
        termux_lib="$workdir/data/data/com.termux/files/usr/lib"

    [ -d "$termux_bin" ] && cp -f "$termux_bin"/* "$MOUNTER_BIN/" 2>/dev/null
    [ -d "$termux_lib" ] && cp -rf "$termux_lib"/* "$MOUNTER_LIB/" 2>/dev/null

    chmod 755 "$MOUNTER_BIN"/* 2>/dev/null
    return 0
}

# --- Install a package ---
install_pkg() {
    local pkg="$1" optional="$2"
    echo "[bootstrap] 📥 Installing $pkg..." | tee -a "$LOG"

    local rel_path
    rel_path=$(resolve_deb "$pkg")
    if [ -z "$rel_path" ]; then
        echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Package '$pkg' not found in index." | tee -a "$LOG"
        [ -n "$optional" ] && return 1
        return 1
    fi

    local deb_url="$TERMUX_REPO/$rel_path"
    local deb_file="$TMPDIR_BOOTSTRAP/${pkg}.deb"
    local work="$TMPDIR_BOOTSTRAP/${pkg}_work"

    if ! download "$deb_url" "$deb_file"; then
        echo "[bootstrap] ${optional:+⚠️ }${optional:-❌} Failed to download $pkg." | tee -a "$LOG"
        return 1
    fi

    if ! extract_deb "$deb_file" "$work"; then
        echo "[bootstrap] ❌ Failed to extract $pkg." | tee -a "$LOG"
        return 1
    fi

    echo "[bootstrap] ✅ $pkg installed." | tee -a "$LOG"
    rm -rf "$work" "$deb_file"
    return 0
}

# --- Main install loop ---
FAILED_REQUIRED=""
for pkg in $REQUIRED_PKGS; do
    install_pkg "$pkg" || FAILED_REQUIRED="$FAILED_REQUIRED $pkg"
done

for pkg in $OPTIONAL_PKGS; do
    install_pkg "$pkg" optional || \
        echo "[bootstrap] ⚠️  Optional package '$pkg' skipped — NTFS write support unavailable." | tee -a "$LOG"
done

# Cleanup temp
rm -rf "$TMPDIR_BOOTSTRAP"

if [ -n "$FAILED_REQUIRED" ]; then
    echo "[bootstrap] ❌ Required packages failed:$FAILED_REQUIRED" | tee -a "$LOG"
    exit 1
fi

echo "[bootstrap] 🎊 Bootstrap complete. Binaries at $MOUNTER_BIN" | tee -a "$LOG"
exit 0

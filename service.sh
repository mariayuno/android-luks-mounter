#!/system/bin/sh
# 🤖 Android LUKS Mounter Service Script
# 👤 Author: Rex Ackermann
# 📝 Purpose: Event-driven service that mounts/unmounts drives on uevent with
#    a lock to prevent concurrent mounter runs, and a health-check poll fallback.

LOG_FILE="/data/local/tmp/mounter.log"
LOCK_FILE="/data/local/tmp/mounter.lock"
HEALTH_INTERVAL=60
INOTIFYWAIT="/data/data/com.termux/files/usr/bin/inotifywait"

# --- ⏳ Boot Wait ---
until [ -d "/sdcard/Android" ]; do sleep 1; done
until getprop sys.user.0.ce_available 2>/dev/null | grep -q "true"; do sleep 1; done

# --- 📏 Log Rotation ---
rotate_log() {
    [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 10000 ] && \
        tail -n 10000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
}

# --- 🔒 Locked Mount ---
# Uses a lockfile so concurrent triggers (e.g. sda + sda1 firing together) don't
# run two mounter instances simultaneously. The second caller waits until the
# first finishes, then runs once to pick up anything the first missed.
do_mount() {
    rotate_log
    # Acquire lock — wait up to 60s then give up to avoid a stuck lock blocking forever.
    local waited=0
    while ! mkdir "$LOCK_FILE" 2>/dev/null; do
        sleep 1
        waited=$((waited + 1))
        [ "$waited" -ge 60 ] && rm -rf "$LOCK_FILE" && break
    done
    /system/bin/mounter --all >> "$LOG_FILE" 2>&1
    rm -rf "$LOCK_FILE"
}

# --- 🚀 Main ---
# Run once at boot after unlock to catch anything vold grabbed before us.
do_mount

if [ -x "$INOTIFYWAIT" ]; then
    # Health-check poll runs alongside event listener to catch silent bindfs failures.
    (
        while true; do
            sleep "$HEALTH_INTERVAL"
            do_mount
        done
    ) &
    HEALTH_PID=$!

    # Watch CREATE (plug-in) and DELETE (unplug) on /dev/block.
    # On unplug, mounter --all calls cleanup_stale_mounts() which tears down
    # orphaned bindfs views and LUKS mappers whose backing device is gone.
    "$INOTIFYWAIT" -m -q -e create -e delete /dev/block 2>/dev/null | while read -r _dir _event _dev; do
        case "$_dev" in
            sd[a-z]*|mmcblk1*) do_mount ;;
        esac
    done

    kill "$HEALTH_PID" 2>/dev/null

else
    while true; do
        sleep "$HEALTH_INTERVAL"
        do_mount
    done
fi

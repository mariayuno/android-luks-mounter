#!/system/bin/sh
# 🤖 Android LUKS Mounter Service Script
# 👤 Author: Rex Ackermann
# 📝 Purpose: Event-driven service that mounts drives on uevent (block device add)
#    with a slow health-check poll to catch silent bindfs failures.

LOG_FILE="/data/local/tmp/mounter.log"
HEALTH_INTERVAL=60  # seconds between health-check polls
INOTIFYWAIT="/data/data/com.termux/files/usr/bin/inotifywait"

# --- ⏳ Boot Wait ---
# Wait for /sdcard/Android (storage framework up) then CE unlock (FBE PIN entered).
until [ -d "/sdcard/Android" ]; do sleep 1; done
until getprop sys.user.0.ce_available 2>/dev/null | grep -q "true"; do sleep 1; done

# --- 📏 Log Rotation ---
rotate_log() {
    [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 10000 ] && \
        tail -n 10000 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
}

# --- ⚡ Mount Trigger ---
do_mount() {
    rotate_log
    /system/bin/mounter --all >> "$LOG_FILE" 2>&1
}

# --- 🚀 Main ---
# Run once at boot after unlock to catch anything vold grabbed before us.
do_mount

# Prefer inotifywait (Termux: pkg install inotify-tools) for zero-overhead uevent
# detection on /sys/block. Falls back to a slow poll if not installed.
if [ -x "$INOTIFYWAIT" ]; then
    # inotifywait -m: monitor indefinitely, -e create: fires when a new block device
    # directory appears (kernel adds it on device plug-in / uevent ADD).
    # -q: suppress startup banner. --format '%f': just the filename, we don't need it.
    # We also run a background health-check loop alongside the event listener.
    (
        while true; do
            sleep "$HEALTH_INTERVAL"
            do_mount
        done
    ) &
    HEALTH_PID=$!

    "$INOTIFYWAIT" -m -q -e create /sys/block 2>/dev/null | while read -r _dir _event _dev; do
        # Only react to block devices we care about (sd*, mmcblk1*)
        case "$_dev" in
            sd[a-z]*|mmcblk1*) do_mount ;;
        esac
    done

    # inotifywait exited (shouldn't happen) — kill health loop and fall through to poll
    kill "$HEALTH_PID" 2>/dev/null

else
    # Fallback: slow poll. With the sed fix in place this is now cheap (idempotent
    # when everything is already mounted) and 60s is fine for a health check.
    while true; do
        sleep "$HEALTH_INTERVAL"
        do_mount
    done
fi

#!/system/bin/sh
# 🤖 Android LUKS Mounter Service Script
# 👤 Author: Rex Ackermann
# 📝 Purpose: Event-driven service that mounts/unmounts drives on uevent with
#    coalesced triggering (at most one running + one pending) and a health-check poll.

LOG_FILE="/data/local/tmp/mounter.log"
LOCK_FILE="/data/local/tmp/mounter.lock"  # held by the running mounter instance
PENDING_FILE="/data/local/tmp/mounter.pending"  # exists while one trigger is waiting
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

# --- 🔒 Coalesced Mount Trigger ---
# States:
#   nobody holds LOCK       -> acquire it, run immediately
#   LOCK held, no PENDING   -> create PENDING, wait for LOCK, run once, clear PENDING
#   LOCK held, PENDING set  -> drop (a run is already queued, it will see current state)
do_mount() {
    rotate_log

    if mkdir "$LOCK_FILE" 2>/dev/null; then
        # Fast path: no one running, go immediately.
        /system/bin/mounter --all >> "$LOG_FILE" 2>&1
        rm -rf "$LOCK_FILE"
    elif mkdir "$PENDING_FILE" 2>/dev/null; then
        # One run in progress, queue ourselves as the single pending waiter.
        # Wait for the lock with a 60s safety timeout against a stuck lock.
        local waited=0
        while ! mkdir "$LOCK_FILE" 2>/dev/null; do
            sleep 1
            waited=$((waited + 1))
            [ "$waited" -ge 60 ] && rm -rf "$LOCK_FILE" && break
        done
        rm -rf "$PENDING_FILE"
        /system/bin/mounter --all >> "$LOG_FILE" 2>&1
        rm -rf "$LOCK_FILE"
    fi
    # else: LOCK held AND PENDING exists -> drop this trigger silently.
}

# --- 🚀 Main ---
do_mount

if [ -x "$INOTIFYWAIT" ]; then
    (
        while true; do
            sleep "$HEALTH_INTERVAL"
            do_mount
        done
    ) &
    HEALTH_PID=$!

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

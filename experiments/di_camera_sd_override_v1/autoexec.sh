#!/bin/sh

# NX300 one-boot, NAND-free executable override proof.
# Expected SD layout:
#   /mnt/mmc/autoexec.sh
#   /mnt/mmc/di_camera_sd_override_v1/payload/di-camera-app-nx300
# All runtime logs and copies remain in /tmp.

LOG=/tmp/di_camera_sd_override_v1.log
SD_PAYLOAD=/mnt/mmc/di_camera_sd_override_v1/payload/di-camera-app-nx300
TMP_PAYLOAD=/tmp/di-camera-app-nx300
TARGET=/usr/bin/di-camera-app-nx300
EXPECTED_SHA256=c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7
BOUND=0

: > "$LOG" 2>/dev/null || exit 1

log()
{
    printf '%s\n' "$*" >> "$LOG"
}

fail()
{
    log "RESULT=FAIL"
    log "ERROR=$*"
    if [ "$BOUND" = 1 ]; then
        if umount "$TARGET" >> "$LOG" 2>&1; then
            BOUND=0
            log "FAILSAFE_UNMOUNT=OK"
        else
            log "FAILSAFE_UNMOUNT=FAILED_REBOOT_PHYSICALLY"
        fi
    fi
    exit 1
}

camera_pid()
{
    pidof di-camera-app-nx300 2>/dev/null || pidof di-camera-app 2>/dev/null
}

hash_of()
{
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

log "EXPERIMENT=di_camera_sd_override_v1"
log "UPTIME_BEGIN=$(cat /proc/uptime 2>/dev/null)"
log "TARGET=$TARGET"
log "SD_PAYLOAD=$SD_PAYLOAD"

[ -x /usr/bin/sha256sum ] || command -v sha256sum >/dev/null 2>&1 || fail "sha256sum unavailable"
[ -x /bin/mount ] || command -v mount >/dev/null 2>&1 || fail "mount unavailable"
[ -f "$TARGET" ] || fail "target missing"
[ -f "$SD_PAYLOAD" ] || fail "SD payload missing"

PID_BEFORE=$(camera_pid)
[ -z "$PID_BEFORE" ] || fail "camera app already running before verification: $PID_BEFORE"

TARGET_SHA=$(hash_of "$TARGET")
[ -n "$TARGET_SHA" ] || fail "could not hash original target"
log "TARGET_SHA256_BEFORE=$TARGET_SHA"
[ "$TARGET_SHA" = "$EXPECTED_SHA256" ] || fail "original target hash mismatch"

SD_SHA=$(hash_of "$SD_PAYLOAD")
[ -n "$SD_SHA" ] || fail "could not hash SD payload"
log "SD_PAYLOAD_SHA256=$SD_SHA"
[ "$SD_SHA" = "$EXPECTED_SHA256" ] || fail "SD payload hash mismatch"

rm -f "$TMP_PAYLOAD" 2>/dev/null || fail "could not clear stale /tmp payload"
cp "$SD_PAYLOAD" "$TMP_PAYLOAD" >> "$LOG" 2>&1 || fail "copy to /tmp failed"
chmod 755 "$TMP_PAYLOAD" >> "$LOG" 2>&1 || fail "chmod 755 failed"

TMP_SHA=$(hash_of "$TMP_PAYLOAD")
[ -n "$TMP_SHA" ] || fail "could not hash /tmp payload"
log "TMP_PAYLOAD_SHA256=$TMP_SHA"
[ "$TMP_SHA" = "$EXPECTED_SHA256" ] || fail "/tmp payload hash mismatch"

TARGET_ID_BEFORE=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
TMP_ID=$(stat -c '%d:%i' "$TMP_PAYLOAD" 2>/dev/null)
[ -n "$TARGET_ID_BEFORE" ] || fail "could not stat target"
[ -n "$TMP_ID" ] || fail "could not stat /tmp payload"
log "TARGET_DEV_INODE_BEFORE=$TARGET_ID_BEFORE"
log "TMP_DEV_INODE=$TMP_ID"

# Final pre-bind guard. If autoexec lost the race with launchpad, do nothing.
PID_PRE_BIND=$(camera_pid)
[ -z "$PID_PRE_BIND" ] || fail "camera app started before bind: $PID_PRE_BIND"

mount --bind "$TMP_PAYLOAD" "$TARGET" >> "$LOG" 2>&1 || fail "bind mount failed"
BOUND=1

TARGET_SHA_AFTER=$(hash_of "$TARGET")
TARGET_ID_AFTER=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
log "TARGET_SHA256_AFTER=$TARGET_SHA_AFTER"
log "TARGET_DEV_INODE_AFTER=$TARGET_ID_AFTER"
[ "$TARGET_SHA_AFTER" = "$EXPECTED_SHA256" ] || fail "bound target hash mismatch"
[ "$TARGET_ID_AFTER" = "$TMP_ID" ] || fail "bound target is not the /tmp inode"

log "UPTIME_BOUND=$(cat /proc/uptime 2>/dev/null)"
log "RESULT=SUCCESS"
log "ROLLBACK=physical reboot"
exit 0

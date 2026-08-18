#!/bin/sh

mkdir -p /dev/pts
mount -t devpts none /dev/pts
httpd -h /mnt/mmc
inetd /mnt/mmc/inetd.conf

LOG=/tmp/di_camera_sd_override_v2_1.log
SD_PAYLOAD=/mnt/mmc/di-camera-app-nx300-test
ARM_MARKER=/mnt/mmc/di-camera-override.arm
TMP_PAYLOAD=/tmp/di-camera-app-nx300
TARGET=/usr/bin/di-camera-app-nx300
EXPECTED_SHA256=c3932e60f75df886ed5484470be91f2d9ca8f3d6e2c9944cdd0060561fe852a7

DROPBEAR=/mnt/mmc/dropbear-nx300-v3
SD_AUTHORIZED_KEYS=/mnt/mmc/authorized_keys
SD_HOSTKEY_B64=/mnt/mmc/nx300_hostkey.b64
SSH_DIR=/tmp/nxssh
SSH_AUTHORIZED_KEYS=/tmp/nxssh/authorized_keys
SSH_HOSTKEY=/tmp/nx300_hostkey
SSH_PIDFILE=/tmp/dropbear.pid

BOUND=0
REBOOT_REQUIRED=0
PID_PRE_BIND_LOGGED=0
UPTIME_BEFORE_BIND_LOGGED=0
UPTIME_AFTER_BIND_LOGGED=0
OVERRIDE_SUCCESS=0

: > "$LOG" 2>/dev/null || exit 1

log()
{
    printf '%s\n' "$*" >> "$LOG"
}

camera_pid()
{
    PID_LIST=$(pidof di-camera-app-nx300 2>/dev/null)
    [ -n "$PID_LIST" ] || PID_LIST=$(pidof di-camera-app 2>/dev/null)
    [ -n "$PID_LIST" ] || return 0
    set -- $PID_LIST
    printf '%s\n' "$1"
}

hash_of()
{
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
}

log "EXPERIMENT=di_camera_sd_override_v2_1"
log "UPTIME_BEGIN=$(cat /proc/uptime 2>/dev/null)"

# First race guard: intentionally before SHA-256, payload copying or Dropbear.
PID_FIRST_GUARD=$(camera_pid)
[ -n "$PID_FIRST_GUARD" ] || PID_FIRST_GUARD=NONE
log "PID_FIRST_GUARD=$PID_FIRST_GUARD"

run_override()
{
    if [ "$PID_FIRST_GUARD" != NONE ]; then
        log "OVERRIDE_RESULT=SKIPPED"
        log "OVERRIDE_DETAIL=camera app already running at first guard"
        return 0
    fi

    if [ ! -f "$ARM_MARKER" ]; then
        log "OVERRIDE_RESULT=SKIPPED"
        log "OVERRIDE_DETAIL=one-shot arm marker missing"
        log "ONE_SHOT_ARM=NOT_PRESENT"
        return 0
    fi

    if ! command -v sha256sum >/dev/null 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=sha256sum unavailable"
        return 0
    fi
    if ! command -v mount >/dev/null 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=mount unavailable"
        return 0
    fi
    if [ ! -f "$TARGET" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=target missing"
        return 0
    fi
    if [ ! -f "$SD_PAYLOAD" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=SD payload missing"
        return 0
    fi

    TARGET_SHA=$(hash_of "$TARGET")
    log "TARGET_SHA256_BEFORE=$TARGET_SHA"
    if [ "$TARGET_SHA" != "$EXPECTED_SHA256" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=original target hash mismatch"
        return 0
    fi

    SD_SHA=$(hash_of "$SD_PAYLOAD")
    log "SD_PAYLOAD_SHA256=$SD_SHA"
    if [ "$SD_SHA" != "$EXPECTED_SHA256" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=SD payload hash mismatch"
        return 0
    fi

    if ! rm -f "$TMP_PAYLOAD" 2>/dev/null; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=could not clear stale tmp payload"
        return 0
    fi
    if ! cp "$SD_PAYLOAD" "$TMP_PAYLOAD" >> "$LOG" 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=copy to tmp failed"
        return 0
    fi
    if ! chmod 755 "$TMP_PAYLOAD" >> "$LOG" 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=chmod 755 failed"
        return 0
    fi

    TMP_SHA=$(hash_of "$TMP_PAYLOAD")
    log "TMP_PAYLOAD_SHA256=$TMP_SHA"
    if [ "$TMP_SHA" != "$EXPECTED_SHA256" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=tmp payload hash mismatch"
        return 0
    fi

    TARGET_ID_BEFORE=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
    TMP_ID=$(stat -c '%d:%i' "$TMP_PAYLOAD" 2>/dev/null)
    log "TARGET_DEV_INODE_BEFORE=$TARGET_ID_BEFORE"
    log "TMP_PAYLOAD_DEV_INODE=$TMP_ID"
    if [ -z "$TARGET_ID_BEFORE" ] || [ -z "$TMP_ID" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=pre-bind stat failed"
        return 0
    fi

    PID_PRE_BIND=$(camera_pid)
    [ -n "$PID_PRE_BIND" ] || PID_PRE_BIND=NONE
    log "PID_PRE_BIND=$PID_PRE_BIND"
    PID_PRE_BIND_LOGGED=1
    if [ "$PID_PRE_BIND" != NONE ]; then
        log "OVERRIDE_RESULT=SKIPPED"
        log "OVERRIDE_DETAIL=camera app won race before bind"
        return 0
    fi

    if ! rm -f "$ARM_MARKER" 2>/dev/null; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=could not consume one-shot arm marker"
        return 0
    fi
    if ! sync >> "$LOG" 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=sync after arm consumption failed"
        return 0
    fi
    if [ -e "$ARM_MARKER" ]; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=one-shot arm marker still present"
        return 0
    fi
    log "ONE_SHOT_ARM=CONSUMED"

    PID_FINAL_GUARD=$(camera_pid)
    [ -n "$PID_FINAL_GUARD" ] || PID_FINAL_GUARD=NONE
    log "PID_FINAL_GUARD=$PID_FINAL_GUARD"
    if [ "$PID_FINAL_GUARD" != NONE ]; then
        log "OVERRIDE_RESULT=SKIPPED"
        log "OVERRIDE_DETAIL=camera app won race after one-shot disarm"
        return 0
    fi

    UPTIME_BEFORE_BIND=$(cat /proc/uptime 2>/dev/null)
    log "UPTIME_BEFORE_BIND=$UPTIME_BEFORE_BIND"
    UPTIME_BEFORE_BIND_LOGGED=1

    if ! mount --bind "$TMP_PAYLOAD" "$TARGET" >> "$LOG" 2>&1; then
        log "OVERRIDE_RESULT=FAIL"
        log "OVERRIDE_DETAIL=bind mount failed"
        TARGET_ID_AFTER_BIND_ERROR=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
        log "TARGET_DEV_INODE_AFTER_BIND_ERROR=$TARGET_ID_AFTER_BIND_ERROR"
        if [ -n "$TARGET_ID_AFTER_BIND_ERROR" ] && [ "$TARGET_ID_AFTER_BIND_ERROR" != "$TARGET_ID_BEFORE" ]; then
            log "BIND_STATE=AMBIGUOUS_ATTEMPTING_UNMOUNT"
            if umount "$TARGET" >> "$LOG" 2>&1; then
                TARGET_ID_ROLLBACK=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
                log "TARGET_DEV_INODE_AFTER_UNMOUNT=$TARGET_ID_ROLLBACK"
                if [ "$TARGET_ID_ROLLBACK" = "$TARGET_ID_BEFORE" ]; then
                    log "FAILSAFE_UNMOUNT=CONFIRMED"
                    return 0
                fi
            fi
            REBOOT_REQUIRED=1
            log "FAILSAFE_UNMOUNT=UNCONFIRMED"
            log "REBOOT_REQUIRED=1"
            log "MUTATIONS_STOPPED=1"
        fi
        return 0
    fi
    BOUND=1

    UPTIME_AFTER_BIND=$(cat /proc/uptime 2>/dev/null)
    log "UPTIME_AFTER_BIND=$UPTIME_AFTER_BIND"
    UPTIME_AFTER_BIND_LOGGED=1

    TARGET_SHA_AFTER=$(hash_of "$TARGET")
    TARGET_ID_AFTER=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
    log "TARGET_SHA256_AFTER=$TARGET_SHA_AFTER"
    log "TARGET_DEV_INODE_AFTER=$TARGET_ID_AFTER"

    if [ "$TARGET_SHA_AFTER" = "$EXPECTED_SHA256" ] && [ "$TARGET_ID_AFTER" = "$TMP_ID" ]; then
        OVERRIDE_SUCCESS=1
        log "OVERRIDE_RESULT=SUCCESS"
        log "OVERRIDE_DETAIL=bind validated"
        return 0
    fi

    log "OVERRIDE_RESULT=FAIL"
    log "OVERRIDE_DETAIL=post-bind validation failed; attempting failsafe unmount"
    if umount "$TARGET" >> "$LOG" 2>&1; then
        TARGET_ID_ROLLBACK=$(stat -c '%d:%i' "$TARGET" 2>/dev/null)
        log "TARGET_DEV_INODE_AFTER_UNMOUNT=$TARGET_ID_ROLLBACK"
        if [ "$TARGET_ID_ROLLBACK" = "$TARGET_ID_BEFORE" ]; then
            BOUND=0
            log "FAILSAFE_UNMOUNT=CONFIRMED"
            return 0
        fi
        log "FAILSAFE_UNMOUNT=UNCONFIRMED_INODE"
    else
        log "FAILSAFE_UNMOUNT=FAILED"
    fi

    REBOOT_REQUIRED=1
    log "REBOOT_REQUIRED=1"
    log "MUTATIONS_STOPPED=1"
    return 0
}

verify_executed_inode()
{
    VERIFY_COUNT=0
    while [ "$VERIFY_COUNT" -lt 20 ]; do
        CAMERA_PID=$(camera_pid)
        if [ -n "$CAMERA_PID" ]; then
            CAMERA_EXE_PATH=$(readlink "/proc/$CAMERA_PID/exe" 2>/dev/null)
            CAMERA_EXE_ID=$(stat -c '%d:%i' "/proc/$CAMERA_PID/exe" 2>/dev/null)
            TMP_VERIFY_ID=$(stat -c '%d:%i' "$TMP_PAYLOAD" 2>/dev/null)
            log "CAMERA_PID_OBSERVED=$CAMERA_PID"
            log "CAMERA_PROC_EXE=$CAMERA_EXE_PATH"
            log "CAMERA_EXE_DEV_INODE=$CAMERA_EXE_ID"
            log "TMP_PAYLOAD_DEV_INODE=$TMP_VERIFY_ID"
            if [ -n "$CAMERA_EXE_ID" ] && [ "$CAMERA_EXE_ID" = "$TMP_VERIFY_ID" ]; then
                log "EXEC_VERIFY=BOUND_PAYLOAD"
            else
                log "EXEC_VERIFY=ORIGINAL_OR_RACE"
            fi
            return 0
        fi
        VERIFY_COUNT=$((VERIFY_COUNT + 1))
        sleep 1
    done

    log "CAMERA_PID_OBSERVED=NONE"
    log "CAMERA_EXE_DEV_INODE=UNAVAILABLE"
    log "TMP_PAYLOAD_DEV_INODE=$(stat -c '%d:%i' "$TMP_PAYLOAD" 2>/dev/null)"
    log "EXEC_VERIFY=ORIGINAL_OR_RACE"
    return 0
}

start_dropbear()
{
    if [ ! -x "$DROPBEAR" ]; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=binary missing or not executable"
        return 0
    fi
    if [ ! -f "$SD_AUTHORIZED_KEYS" ]; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=authorized_keys missing"
        return 0
    fi
    if [ ! -f "$SD_HOSTKEY_B64" ]; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=base64 host key missing"
        return 0
    fi
    if ! command -v base64 >/dev/null 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=base64 unavailable"
        return 0
    fi

    if ! mkdir -p "$SSH_DIR" >> "$LOG" 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not create runtime directory"
        return 0
    fi
    if ! chmod 700 "$SSH_DIR" >> "$LOG" 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not protect runtime directory"
        return 0
    fi
    if ! rm -f "$SSH_AUTHORIZED_KEYS" "$SSH_HOSTKEY" "$SSH_PIDFILE" 2>/dev/null; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not clear stale runtime files"
        return 0
    fi
    if ! cp "$SD_AUTHORIZED_KEYS" "$SSH_AUTHORIZED_KEYS" >> "$LOG" 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not stage authorized_keys"
        return 0
    fi
    if ! chmod 600 "$SSH_AUTHORIZED_KEYS" >> "$LOG" 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not protect authorized_keys"
        return 0
    fi
    if ! base64 -d "$SD_HOSTKEY_B64" > "$SSH_HOSTKEY" 2>> "$LOG"; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not decode host key"
        return 0
    fi
    if [ ! -s "$SSH_HOSTKEY" ]; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=decoded host key empty"
        return 0
    fi
    if ! chmod 600 "$SSH_HOSTKEY" >> "$LOG" 2>&1; then
        log "DROPBEAR_RESULT=FAIL"
        log "DROPBEAR_DETAIL=could not protect host key"
        return 0
    fi

    "$DROPBEAR" -F -r /tmp/nx300_hostkey -D /tmp/nxssh -p 22 -P /tmp/dropbear.pid -j -k -m >> "$LOG" 2>&1 &
    DROPBEAR_LAUNCH_PID=$!
    log "DROPBEAR_LAUNCH_PID=$DROPBEAR_LAUNCH_PID"
    log "DROPBEAR_RESULT=START_REQUESTED"
    return 0
}

run_override

[ "$PID_PRE_BIND_LOGGED" = 1 ] || log "PID_PRE_BIND=NOT_REACHED"
[ "$UPTIME_BEFORE_BIND_LOGGED" = 1 ] || log "UPTIME_BEFORE_BIND=NOT_REACHED"
[ "$UPTIME_AFTER_BIND_LOGGED" = 1 ] || log "UPTIME_AFTER_BIND=NOT_REACHED"

if [ "$REBOOT_REQUIRED" = 1 ]; then
    log "DROPBEAR_RESULT=NOT_STARTED_REBOOT_REQUIRED"
    log "FINAL_RESULT=REBOOT_REQUIRED"
    exit 0
fi

if [ "$OVERRIDE_SUCCESS" = 1 ]; then
    verify_executed_inode &
    log "EXEC_VERIFY_WATCHER=STARTED"
else
    log "CAMERA_PID_OBSERVED=NOT_WATCHED_OVERRIDE_NOT_BOUND"
    log "CAMERA_EXE_DEV_INODE=NOT_WATCHED_OVERRIDE_NOT_BOUND"
    log "TMP_PAYLOAD_DEV_INODE=$(stat -c '%d:%i' "$TMP_PAYLOAD" 2>/dev/null)"
    log "EXEC_VERIFY=ORIGINAL_OR_RACE"
fi

start_dropbear
log "FINAL_RESULT=CONTINUE_BOOT"
log "ROLLBACK=reboot clears current bind; restore/remove SD autoexec to prevent reapply"
exit 0

#!/bin/sh

# NX300 CT3 console routing probe v1.1 - read-only.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then
        probe_root="$candidate"
        break
    fi
done

[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_CONSOLE_V1_1.LOG"
before_log="$probe_root/CT3_DLOG_BEFORE_V1_1.LOG"
after_log="$probe_root/CT3_DLOG_AFTER_V1_1.LOG"

sleep 12

camera_pid="$(pidof di-camera-app 2>/dev/null)"
if [ -z "$camera_pid" ]; then
    camera_pid="$(pidof di-camera-app-nx300 2>/dev/null)"
fi
if [ -z "$camera_pid" ]; then
    camera_pid="$(ps 2>/dev/null | grep 'di-camera-app' | grep -v grep | sed -n '1s/^ *\([0-9][0-9]*\).*/\1/p')"
fi

{
    echo "=== CT3 CONSOLE PROBE V1.1 START ==="
    date
    uname -a
    echo "uid=$(id 2>/dev/null)"
    echo "camera_pid=$camera_pid"
    echo "--- camera process ---"
    ps 2>/dev/null | grep 'di-camera-app' | grep -v grep
    if [ -n "$camera_pid" ] && [ -d "/proc/$camera_pid" ]; then
        echo "--- cmdline ---"
        tr '\000' ' ' < "/proc/$camera_pid/cmdline"
        echo
        echo "--- status ---"
        sed -n '1,24p' "/proc/$camera_pid/status"
        echo "--- file descriptors ---"
        ls -l "/proc/$camera_pid/fd"
        echo "--- fdinfo 0/1/2 ---"
        for fd in 0 1 2; do
            echo "fd=$fd"
            cat "/proc/$camera_pid/fdinfo/$fd" 2>/dev/null
        done
    fi
    echo "--- SysV queues ---"
    cat /proc/sysvipc/msg 2>/dev/null
    echo "--- existing logs ---"
    ls -l /var/log/dlog* 2>/dev/null
} >> "$probe_log" 2>&1

/usr/bin/dlogutil -d -v time '*:V' > "$before_log" 2>&1

{
    echo "--- send commands ---"
    /usr/bin/st cap cis info
    echo "info_rc=$?"
    /usr/bin/st cap cis regr 0340
    echo "regr_0340_rc=$?"
    /usr/bin/st cap cis regr 0342
    echo "regr_0342_rc=$?"
    /usr/bin/st cap cis regr 3404
    echo "regr_3404_rc=$?"
} >> "$probe_log" 2>&1

sleep 2
/usr/bin/dlogutil -d -v time '*:V' > "$after_log" 2>&1

{
    echo "--- persistent dlog tail ---"
    tail -n 200 /var/log/dlog 2>/dev/null
    echo "=== CT3 CONSOLE PROBE V1.1 END ==="
    date
} >> "$probe_log" 2>&1

sync
exit 0

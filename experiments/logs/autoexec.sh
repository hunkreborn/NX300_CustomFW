#!/bin/sh

# NX300 CT3 console capture v1.2 - read-only sensor probe.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then
        probe_root="$candidate"
        break
    fi
done
[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_STRACE_V1_2.LOG"
trace_log="$probe_root/CT3_REGISTER_TRACE_V1_2.LOG"

sleep 12

camera_pid="$(pidof di-camera-app 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(pidof di-camera-app-nx300 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(ps 2>/dev/null | grep 'di-camera-app' | grep -v grep | sed -n '1s/^ *\([0-9][0-9]*\).*/\1/p')"

shell_tid=""
if [ -n "$camera_pid" ]; then
    for task_dir in /proc/$camera_pid/task/*; do
        [ -f "$task_dir/comm" ] || continue
        task_name="$(cat "$task_dir/comm" 2>/dev/null)"
        case "$task_name" in
            shell_di_camera*)
                shell_tid="${task_dir##*/}"
                break
                ;;
        esac
    done
fi

{
    echo "=== CT3 STRACE PROBE V1.2 START ==="
    date
    echo "uid=$(id 2>/dev/null)"
    echo "camera_pid=$camera_pid"
    echo "shell_tid=$shell_tid"
    echo "--- task names ---"
    if [ -n "$camera_pid" ]; then
        for task_dir in /proc/$camera_pid/task/*; do
            [ -f "$task_dir/comm" ] || continue
            echo "${task_dir##*/} $(cat "$task_dir/comm" 2>/dev/null)"
        done
    fi
} >> "$probe_log" 2>&1

if [ -z "$shell_tid" ]; then
    echo "ERROR: shell command thread not found" >> "$probe_log"
    exit 3
fi

: > "$trace_log"
/usr/bin/strace -p "$shell_tid" -e trace=write -s 512 -o "$trace_log" &
strace_pid=$!
sleep 1

{
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
kill "$strace_pid" 2>/dev/null
wait "$strace_pid" 2>/dev/null

{
    echo "strace_pid=$strace_pid"
    echo "trace_bytes=$(wc -c < "$trace_log" 2>/dev/null)"
    echo "=== CT3 STRACE PROBE V1.2 END ==="
    date
} >> "$probe_log" 2>&1

sync
exit 0

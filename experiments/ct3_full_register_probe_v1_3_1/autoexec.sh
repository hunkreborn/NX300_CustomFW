#!/bin/sh

# NX300 CT3 full register baseline v1.3.1 - sensor read-only.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then probe_root="$candidate"; break; fi
done
[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_FULL_V1_3_1.LOG"
trace_log="$probe_root/CT3_FULL_REGISTER_TRACE_V1_3_1.LOG"

sleep 12
camera_pid="$(pidof di-camera-app 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(pidof di-camera-app-nx300 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(ps 2>/dev/null | grep 'di-camera-app' | grep -v grep | sed -n '1s/^ *\([0-9][0-9]*\).*/\1/p')"

shell_tid=""
if [ -n "$camera_pid" ]; then
    for task_dir in /proc/$camera_pid/task/*; do
        [ -f "$task_dir/comm" ] || continue
        case "$(cat "$task_dir/comm" 2>/dev/null)" in
            shell_di_camera*) shell_tid="${task_dir##*/}"; break ;;
        esac
    done
fi

{
    echo "=== CT3 FULL REGISTER PROBE V1.3.1 START ==="
    date
    echo "uid=$(id 2>/dev/null)"
    echo "camera_pid=$camera_pid"
    echo "shell_tid=$shell_tid"
} >> "$probe_log" 2>&1

if [ -z "$shell_tid" ]; then
    echo "ERROR: shell command thread not found" >> "$probe_log"
    exit 3
fi

: > "$trace_log"
# Include msgrcv so the old strace stays synchronized when attaching while the
# shell thread is blocked waiting for its next command.
/usr/bin/strace -p "$shell_tid" -e trace=msgrcv,write -s 512 -o "$trace_log" &
strace_pid=$!
sleep 1

/usr/bin/st cap cis info
echo "info_rc=$?" >> "$probe_log"
/bin/usleep 200000

for reg in 0100 0112 0340 0342 0344 0346 0348 034a 034c 034e 0380 0382 0384 0386 0900 0901 3142 3148 314a 31d2 3224 3226 3228 322a 3242 3252 3404 3406 3408 3416 3418 341a 341c 341e 3420 3422 3424 3426 342a 342c 342e 3430 3432 3434 343c 343e 3440 3466 347a 347c 3480 3482 3484 3486 3488 348a 348c 348e 3490 3492 4022 6100 6306 700c 702c 7032; do
    /usr/bin/st cap cis regr "$reg"
    echo "regr_${reg}_rc=$?" >> "$probe_log"
    /bin/usleep 100000
done

sleep 2
kill "$strace_pid" 2>/dev/null
wait "$strace_pid" 2>/dev/null

{
    echo "strace_pid=$strace_pid"
    echo "trace_bytes=$(wc -c < "$trace_log" 2>/dev/null)"
    echo "read_results=$(grep -c 'CIS_READ ADDRESS.*DATA' "$trace_log" 2>/dev/null)"
    echo "=== CT3 FULL REGISTER PROBE V1.3.1 END ==="
    date
} >> "$probe_log" 2>&1
sync
exit 0

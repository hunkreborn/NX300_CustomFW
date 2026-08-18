#!/bin/sh

# NX300 CT3 factory live-mode probe v1.4.
# Active but limited to factory DebugProcess commands: live, regr, stop.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then probe_root="$candidate"; break; fi
done
[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_FACTORY_LIVE_V1_4.LOG"
trace_log="$probe_root/CT3_FACTORY_LIVE_TRACE_V1_4.LOG"
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

strace_pid=""
watchdog_pid=""
cleanup_probe() {
    /usr/bin/st cap cis stop >/dev/null 2>&1
    [ -z "$watchdog_pid" ] || kill "$watchdog_pid" 2>/dev/null
    [ -z "$strace_pid" ] || kill "$strace_pid" 2>/dev/null
}
trap cleanup_probe EXIT INT TERM

{
    echo "=== CT3 FACTORY LIVE PROBE V1.4 START ==="
    date
    echo "uid=$(id 2>/dev/null)"
    echo "camera_pid=$camera_pid shell_tid=$shell_tid"
} >> "$probe_log" 2>&1

if [ -z "$shell_tid" ]; then
    echo "ERROR: shell command thread not found" >> "$probe_log"
    exit 3
fi

: > "$trace_log"
/usr/bin/strace -p "$shell_tid" -e trace=msgrcv,write -s 512 -o "$trace_log" &
strace_pid=$!
sleep 1

# Independent safety stop if the main script stalls.
(
    sleep 20
    /usr/bin/st cap cis stop >/dev/null 2>&1
    echo "WATCHDOG_STOP $(date)" >> "$probe_log"
) &
watchdog_pid=$!

/usr/bin/st cap cis live
echo "live_rc=$?" >> "$probe_log"
sleep 1
/usr/bin/st cap cis info
echo "info_live_rc=$?" >> "$probe_log"
/bin/usleep 200000

for reg in 0100 0112 0340 0342 0344 0346 0348 034a 034c 034e 0380 0382 0384 0386 0900 0901 3142 3148 314a 31d2 3224 3226 3228 322a 3242 3252 3404 3406 3408 3416 3418 341a 341c 341e 3420 3422 3424 3426 342a 342c 342e 3430 3432 3434 343c 343e 3440 3466 347a 347c 3480 3482 3484 3486 3488 348a 348c 348e 3490 3492 4022 6100 6306 700c 702c 7032; do
    /usr/bin/st cap cis regr "$reg"
    /bin/usleep 100000
done

/usr/bin/st cap cis stop
echo "stop_rc=$?" >> "$probe_log"
sleep 1
/usr/bin/st cap cis info
echo "info_after_stop_rc=$?" >> "$probe_log"
sleep 1

{
    echo "trace_bytes=$(wc -c < "$trace_log" 2>/dev/null)"
    echo "read_results=$(grep -c 'CIS_READ ADDRESS.*DATA' "$trace_log" 2>/dev/null)"
    echo "=== CT3 FACTORY LIVE PROBE V1.4 END ==="
    date
} >> "$probe_log" 2>&1

exit 0

#!/bin/sh

# CT3 active-live register read v1.4.3.
# Uses strace's independent write-data dump to bypass its ARM syscall formatter bug.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then probe_root="$candidate"; break; fi
done
[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_LIVE_READ_HEXDUMP_V1_4_3.LOG"
trace_log="$probe_root/CT3_LIVE_READ_HEXDUMP_TRACE_V1_4_3.LOG"
camera_pid="$(pidof di-camera-app 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(pidof di-camera-app-nx300 2>/dev/null)"
shell_tid=""
for task_dir in /proc/$camera_pid/task/*; do
    [ -f "$task_dir/comm" ] || continue
    case "$(cat "$task_dir/comm" 2>/dev/null)" in
        shell_di_camera*) shell_tid="${task_dir##*/}"; break ;;
    esac
done

strace_pid=""
watchdog_pid=""
cleanup_hexdump() {
    /usr/bin/st cap cis stop >/dev/null 2>&1
    [ -z "$watchdog_pid" ] || kill "$watchdog_pid" 2>/dev/null
    [ -z "$strace_pid" ] || kill "$strace_pid" 2>/dev/null
}
trap cleanup_hexdump EXIT INT TERM

{
    echo "=== CT3 LIVE READ HEXDUMP V1.4.3 START ==="
    date
    echo "camera_pid=$camera_pid shell_tid=$shell_tid"
} >> "$probe_log" 2>&1
[ -n "$shell_tid" ] || exit 3

(
    sleep 15
    /usr/bin/st cap cis stop >/dev/null 2>&1
    echo "WATCHDOG_STOP $(date)" >> "$probe_log"
) &
watchdog_pid=$!

/usr/bin/st cap cis live
echo "live_rc=$?" >> "$probe_log"
sleep 2

: > "$trace_log"
# Keep the full syscall stream for synchronization. -e write=all emits an
# independent hex/ASCII dump of every buffer written by the command thread.
/usr/bin/strace -p "$shell_tid" -s 512 -e write=all -o "$trace_log" &
strace_pid=$!
sleep 1

/usr/bin/st cap cis info
/bin/usleep 200000
for reg in 0340 0342 3404; do
    /usr/bin/st cap cis regr "$reg"
    /bin/usleep 300000
done
sleep 1

kill "$strace_pid" 2>/dev/null
wait "$strace_pid" 2>/dev/null
strace_pid=""
/usr/bin/st cap cis stop
echo "stop_rc=$?" >> "$probe_log"
sleep 1

{
    echo "trace_bytes=$(wc -c < "$trace_log" 2>/dev/null)"
    echo "address_markers=$(grep -c 'CIS_READ ADDRES' "$trace_log" 2>/dev/null)"
    echo "=== CT3 LIVE READ HEXDUMP V1.4.3 END ==="
    date
} >> "$probe_log" 2>&1
exit 0

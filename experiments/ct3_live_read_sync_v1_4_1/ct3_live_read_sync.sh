#!/bin/sh

# CT3 live read synchronization test v1.4.1.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then probe_root="$candidate"; break; fi
done
[ -n "$probe_root" ] || exit 2

probe_log="$probe_root/CT3_LIVE_READ_SYNC_V1_4_1.LOG"
trace_log="$probe_root/CT3_LIVE_READ_SYNC_TRACE_V1_4_1.LOG"
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
cleanup_sync() {
    /usr/bin/st cap cis stop >/dev/null 2>&1
    [ -z "$watchdog_pid" ] || kill "$watchdog_pid" 2>/dev/null
    [ -z "$strace_pid" ] || kill "$strace_pid" 2>/dev/null
}
trap cleanup_sync EXIT INT TERM

{
    echo "=== CT3 LIVE READ SYNC V1.4.1 START ==="
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

# Configure first, without ptrace attached.
/usr/bin/st cap cis live
echo "live_rc=$?" >> "$probe_log"
sleep 2

# Attach only after factory live configuration has completed.
: > "$trace_log"
/usr/bin/strace -p "$shell_tid" -e trace=msgrcv,write -s 512 -o "$trace_log" &
strace_pid=$!
sleep 1

/usr/bin/st cap cis info
/bin/usleep 200000
for reg in 0340 0342 3404; do
    /usr/bin/st cap cis regr "$reg"
    /bin/usleep 200000
done
sleep 1

# Detach before the stop command to avoid another long driver transition.
kill "$strace_pid" 2>/dev/null
wait "$strace_pid" 2>/dev/null
strace_pid=""

/usr/bin/st cap cis stop
echo "stop_rc=$?" >> "$probe_log"
sleep 1

{
    echo "trace_bytes=$(wc -c < "$trace_log" 2>/dev/null)"
    echo "read_results=$(grep -c 'CIS_READ ADDRESS.*DATA' "$trace_log" 2>/dev/null)"
    echo "=== CT3 LIVE READ SYNC V1.4.1 END ==="
    date
} >> "$probe_log" 2>&1
exit 0

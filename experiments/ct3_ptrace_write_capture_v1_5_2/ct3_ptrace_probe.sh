#!/bin/sh

probe_root=/mnt/mmc
[ -d "$probe_root" ] || probe_root=/sdcard
[ -d "$probe_root" ] || exit 2
summary="$probe_root/CT3_PTRACE_V1_5_2.LOG"
capture="$probe_root/CT3_PTRACE_WRITES_V1_5_2.LOG"
tool="$probe_root/arm_write_capture_v1_5_2"
camera_pid="$(pidof di-camera-app 2>/dev/null)"
[ -n "$camera_pid" ] || camera_pid="$(pidof di-camera-app-nx300 2>/dev/null)"
shell_tid=""
for task_dir in /proc/$camera_pid/task/*; do
    [ -f "$task_dir/comm" ] || continue
    case "$(cat "$task_dir/comm" 2>/dev/null)" in
        shell_di_camera*) shell_tid="${task_dir##*/}"; break ;;
    esac
done

capture_pid=""
watchdog_pid=""
cleanup_probe() {
    /usr/bin/st cap cis stop >/dev/null 2>&1
    [ -z "$capture_pid" ] || kill -TERM "$capture_pid" 2>/dev/null
    [ -z "$watchdog_pid" ] || kill "$watchdog_pid" 2>/dev/null
    [ -z "$camera_pid" ] || kill -CONT "$camera_pid" 2>/dev/null
}
trap cleanup_probe EXIT INT TERM

{
    echo "=== CT3 PTRACE V1.5.2 START ==="
    date
    echo "camera_pid=$camera_pid shell_tid=$shell_tid"
} >> "$summary" 2>&1
[ -x "$tool" ] || { echo "capture_tool_missing" >> "$summary"; exit 3; }
[ -n "$shell_tid" ] || { echo "shell_tid_missing" >> "$summary"; exit 4; }

/usr/bin/st cap cis live
echo "live_rc=$?" >> "$summary"
sleep 2
"$tool" "$shell_tid" "$capture" 2>> "$summary" &
capture_pid=$!

# Independent hard watchdog: terminate tracer, then force camera app runnable.
(
    sleep 10
    kill -TERM "$capture_pid" 2>/dev/null
    sleep 1
    kill -KILL "$capture_pid" 2>/dev/null
    kill -CONT "$camera_pid" 2>/dev/null
    echo "WATCHDOG_FIRED $(date)" >> "$summary"
) &
watchdog_pid=$!

sleep 1
/usr/bin/st cap cis info
/bin/usleep 200000
for reg in 0340 0342 3404; do
    /usr/bin/st cap cis regr "$reg"
    /bin/usleep 300000
done
sleep 1
kill -TERM "$capture_pid" 2>/dev/null
wait "$capture_pid" 2>/dev/null
capture_rc=$?
capture_pid=""
kill "$watchdog_pid" 2>/dev/null
watchdog_pid=""
kill -CONT "$camera_pid" 2>/dev/null
/usr/bin/st cap cis stop
echo "stop_rc=$?" >> "$summary"
{
    echo "capture_rc=$capture_rc"
    echo "capture_bytes=$(wc -c < "$capture" 2>/dev/null)"
    echo "tracer_after=$(cat /proc/$shell_tid/status 2>/dev/null | grep TracerPid)"
    echo "=== CT3 PTRACE V1.5.2 END ==="
    date
} >> "$summary" 2>&1
exit 0

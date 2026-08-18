#!/bin/sh

# telnetd login wrapper: ignore all arguments supplied by telnetd.
console_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then console_root="$candidate"; break; fi
done

if [ -n "$console_root" ]; then
    {
        echo "=== SHELL SESSION ==="
        date
        echo "pid=$$ ppid=$PPID args=$*"
        echo "uid=$(id 2>/dev/null)"
    } >> "$console_root/NX300_SHELL_SESSIONS.LOG" 2>&1
fi

export PATH=/sbin:/bin:/usr/sbin:/usr/bin
export TERM=vt100
cd "$console_root" 2>/dev/null || cd /

exec /bin/sh -i

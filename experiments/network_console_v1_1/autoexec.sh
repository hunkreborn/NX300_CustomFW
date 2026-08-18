#!/bin/sh

# NX300 temporary network console v1.1.
# Requires nx300_shell.sh in the same SD-card root.

console_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -f "$candidate/nx300_shell.sh" ]; then
        console_root="$candidate"
        break
    fi
done
[ -n "$console_root" ] || exit 2

console_log="$console_root/NX300_NETWORK_CONSOLE_V1_1.LOG"
shell_wrapper="$console_root/nx300_shell.sh"

{
    echo "=== NX300 NETWORK CONSOLE V1.1 START ==="
    date
    echo "uid=$(id 2>/dev/null)"
    echo "wrapper=$shell_wrapper"
    ls -l "$shell_wrapper"
} >> "$console_log" 2>&1

# telnetd may append login-style arguments. The wrapper deliberately ignores
# them and starts an interactive shell attached to telnetd's PTY.
/usr/sbin/telnetd -p 23 -l "$shell_wrapper" >> "$console_log" 2>&1
echo "telnetd_23_rc=$?" >> "$console_log"
/usr/sbin/telnetd -p 22 -l "$shell_wrapper" >> "$console_log" 2>&1
echo "telnetd_22_rc=$?" >> "$console_log"

sleep 1
{
    /bin/netstat -lntp 2>/dev/null
    echo "telnetd_pids=$(pidof telnetd 2>/dev/null)"
    echo "=== NX300 NETWORK CONSOLE V1.1 READY ==="
    date
} >> "$console_log" 2>&1

sync
exit 0

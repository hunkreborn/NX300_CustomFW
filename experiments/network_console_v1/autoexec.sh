#!/bin/sh

# NX300 temporary network console v1.
# SECURITY: exposes an unauthenticated root shell on TCP 22 and TCP 23.

console_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then console_root="$candidate"; break; fi
done
[ -n "$console_root" ] || exit 2

console_log="$console_root/NX300_NETWORK_CONSOLE.LOG"

{
    echo "=== NX300 NETWORK CONSOLE START ==="
    date
    echo "uid=$(id 2>/dev/null)"
    echo "interfaces before start:"
    /sbin/ifconfig 2>/dev/null
    echo "listeners before start:"
    /bin/netstat -lntp 2>/dev/null
} >> "$console_log" 2>&1

# -l /bin/sh deliberately bypasses login/PAM. Both listeners speak Telnet;
# port 22 is not an SSH service.
/usr/sbin/telnetd -p 23 -l /bin/sh >> "$console_log" 2>&1
echo "telnetd_23_rc=$?" >> "$console_log"

/usr/sbin/telnetd -p 22 -l /bin/sh >> "$console_log" 2>&1
echo "telnetd_22_rc=$?" >> "$console_log"

sleep 1
{
    echo "listeners after start:"
    /bin/netstat -lntp 2>/dev/null
    echo "telnetd pids:"
    pidof telnetd 2>/dev/null
    echo "=== NX300 NETWORK CONSOLE READY ==="
    date
} >> "$console_log" 2>&1

sync
exit 0

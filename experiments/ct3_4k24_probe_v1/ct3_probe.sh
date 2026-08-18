#!/bin/sh

# Read-only CT3 baseline collector. No sensor register is written.

probe_root=""
for candidate in /mnt/mmc /sdcard; do
    if [ -d "$candidate" ]; then
        probe_root="$candidate"
        break
    fi
done

if [ -z "$probe_root" ]; then
    exit 2
fi

probe_log="$probe_root/CT3_PROBE_V1.LOG"

{
    echo "=== CT3 4K24 PROBE V1 START ==="
    date
    uname -a
    echo "mount=$probe_root"
    echo "uid=$(id 2>/dev/null)"
    echo "camera processes:"
    ps 2>/dev/null | grep -E 'di-camera|slpcam' | grep -v grep
    echo "st binary:"
    ls -l /usr/bin/st
    echo "waiting for camera service"
} >> "$probe_log" 2>&1

# Give the camera application and capture service time to initialize.
sleep 12

{
    echo "--- st cap cis info ---"
    /usr/bin/st cap cis info

    echo "--- CT3 frame/window/timing registers ---"
    for reg in 0340 0342 3142 31d2 3224 3226 3228 322a 3242 3252 3404 3406 3408 3416 3418 341a 341c 341e 3420 3422 3424 3426 342a 342c 342e 3430 3432 3434 343c 343e 3440 3466 347a 347c 3480 3482 3484 3486 3488 348a 348c 348e 3490 3492 4022 6100 6306 700c 702c 7032; do
        echo "REGISTER 0x$reg"
        /usr/bin/st cap cis regr "$reg"
    done

    echo "=== CT3 4K24 PROBE V1 END ==="
    date
} >> "$probe_log" 2>&1

sync
exit 0

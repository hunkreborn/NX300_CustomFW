#!/bin/sh

# NX300 CT3 4K24 research - read-only probe v1
# Copy this file and ct3_probe.sh to the SD-card root.

for probe_root in /mnt/mmc /sdcard; do
    if [ -f "$probe_root/ct3_probe.sh" ]; then
        /bin/sh "$probe_root/ct3_probe.sh" >> "$probe_root/ct3_probe_boot.log" 2>&1 &
        exit 0
    fi
done

exit 1

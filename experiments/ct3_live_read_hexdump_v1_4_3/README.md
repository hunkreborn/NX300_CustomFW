# CT3 live register read hexdump v1.4.3

Temporary, non-persistent NX300 probe. It selects the factory `cis live`
profile, traces only the existing `shell_di_camera` thread, and reads CT3
registers `0x0340`, `0x0342`, and `0x3404`.

The full syscall stream is retained for ARM ptrace synchronization. The
additional `strace -e write=all` qualifier records an independent hex/ASCII
dump of each output buffer, bypassing the formatter corruption observed in
v1.4.2. A 15-second watchdog and the exit trap issue `cis stop`.

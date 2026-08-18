# CT3 ptrace write capture v1.5.2

Safety revision after the v1.5.1 camera hang. Signal handlers use `sigaction`
without `SA_RESTART`. If shutdown interrupts `wait4`, the tracer forces a
ptrace-stop, reaps it, and reaches explicit detach. The wrapper adds an
independent 10-second watchdog, forced tracer termination, and `SIGCONT` for
the camera app. It records the final `TracerPid`.

Sensor commands remain factory `cis live`, read-only `info` and `regr` for
`0x0340`, `0x0342`, `0x3404`, followed by `cis stop`.

Build revision 2 casts ARM `r1` to `unsigned long` before pointer validation.
NX300 userspace addresses commonly have bit 31 set and were rejected as
negative signed longs by the first build, producing a safe but empty capture.

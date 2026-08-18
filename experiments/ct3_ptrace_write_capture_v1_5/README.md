# CT3 ptrace write capture v1.5

Temporary NX300 experiment. `arm_write_capture` is a small static ARM EABI
tracer that observes the existing `shell_di_camera` thread. At every ARM
`write` syscall-stop it reads `r1` (buffer) and `r2` (length) directly and
dumps the tracee memory. It deliberately does not use strace's entry/exit
state machine, which is corrupted by the camera's old ARM ptrace behavior.

The wrapper selects the existing factory `cis live` mode, queries information
and registers `0x0340`, `0x0342`, `0x3404`, then stops the sensor. It does not
write sensor registers or install persistent camera components.

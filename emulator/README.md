# Samsung NX300 behavioral emulator

Version 0.1 is a safe digital twin for reverse-engineering experiments. It
models observed NX300 state and interfaces; it is **not** cycle-accurate DRIMe
IV emulation and does not claim to boot the Samsung kernel.

Implemented:

- ARMv7/DRIMe IV identity, kernel, memory and mount snapshots;
- a read-only virtual `/proc`, `/sys`, root filesystem and selected binaries;
- HDMI disconnected/connected state and advertised modes;
- measured CT3 liveview registers and 304 MHz timing calculation;
- a clearly labelled, unverified factory-60 timing estimate;
- safe command shell with mutating operations rejected.

Run directly:

```bash
cd emulator
PYTHONPATH=. python3 -m nx300_emulator -- id
PYTHONPATH=. python3 -m nx300_emulator --scenario hdmi-connected -- \
  cat /sys/class/drm/card0-HDMI-A-1/status
PYTHONPATH=. python3 -m nx300_emulator -- st cap cis info
PYTHONPATH=. python3 -m nx300_emulator --repl
```

Run tests:

```bash
cd emulator
PYTHONPATH=. python3 -m unittest discover -s tests -v
```

## Accuracy boundary

Measured values are sourced from the project findings. Estimated values are
labelled at runtime. Future layers can add MMIO register models, ioctl ABI
replay, recorded event traces and eventually a custom QEMU DRIMe IV machine.

## Visual preview with hot reload

```bash
python3 visual/server.py
```

Open `http://127.0.0.1:8300`. The 800×480 preview reloads after changes under
`visual/web/` or the original NX300 image-resource directory. The original
firmware tree is served read-only; make editable copies of assets when needed.

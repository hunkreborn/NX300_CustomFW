from __future__ import annotations

import shlex

from .model import NX300State


class EmulatorShell:
    def __init__(self, state: NX300State):
        self.state = state

    def run(self, command: str) -> tuple[int, str]:
        try:
            argv = shlex.split(command)
        except ValueError as exc:
            return 2, f"parse error: {exc}\n"
        if not argv:
            return 0, ""
        if argv[0] in {"rm", "mv", "cp", "dd", "mount", "umount", "kill", "reboot", "poweroff", "chmod", "chown"}:
            return 126, f"nx300-emulator: blocked mutating command: {argv[0]}\n"
        try:
            if argv == ["id"]:
                return 0, "uid=0(root) gid=0(root)\n"
            if argv == ["uname", "-a"]:
                return 0, "Linux nx300 3.5.0+ #24 PREEMPT Mon Feb 3 14:56:56 KST 2014 armv7l GNU/Linux\n"
            if argv[0] == "cat" and len(argv) == 2:
                return 0, self.state.cat(argv[1])
            if argv[0] == "ls":
                path = next((a for a in reversed(argv[1:]) if not a.startswith("-")), ".")
                return 0, "\n".join(self.state.listdir(path)) + "\n"
            if argv == ["ps"]:
                return 0, (
                    " PID TTY          TIME CMD\n"
                    "   1 ?        00:00:01 init\n"
                    f" {self.state.camera_pid} ?        00:00:30 di-camera-app-n\n"
                )
            if argv[:3] == ["st", "cap", "cis"]:
                return self._cis(argv[3:])
            if argv == ["help"]:
                return 0, "id, uname -a, cat PATH, ls PATH, ps, st cap cis info|regr REG, state\n"
            if argv == ["state"]:
                p = self.state.profile
                return 0, (
                    f"hdmi_connected={self.state.hdmi_connected}\n"
                    f"hdmi_enabled={self.state.hdmi_enabled}\n"
                    f"hdmi_dpms={self.state.hdmi_dpms}\n"
                    f"ct3_profile={p.name}\n"
                )
            return 127, f"nx300-emulator: command not implemented: {argv[0]}\n"
        except FileNotFoundError as exc:
            return 1, f"No such virtual path: {exc.args[0]}\n"

    def _cis(self, args: list[str]) -> tuple[int, str]:
        p = self.state.profile
        if args == ["info"]:
            return 0, (
                "## IMAGE SENSOR INFORMATION [CT3]\n"
                f"Mode : {p.name}\nFrame rate : {p.fps:.6f}fps\n"
                f"frame length : {p.frame_length} (0x{p.frame_length:04x})\n"
                f"line length : {p.line_length} (0x{p.line_length:04x})\n"
                f"pixel clock : {p.pixel_clock_hz / 1_000_000:.6f}MHz\n"
                f"note : {p.description}\n"
            )
        if len(args) == 2 and args[0] == "regr":
            reg = int(args[1], 16)
            values = {0x0340: p.frame_length, 0x0342: p.line_length, 0x3404: p.mode_register}
            if reg not in values:
                return 1, f"CIS_READ ADDRESS : {reg:x}, DATA : unknown\n"
            return 0, f"CIS_READ ADDRESS : {reg:x}, DATA : {values[reg]:x}\n"
        if args and args[0] == "regw":
            return 126, "nx300-emulator: sensor register writes are blocked\n"
        return 2, "usage: st cap cis info | regr HEX_REGISTER\n"

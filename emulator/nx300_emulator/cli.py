from __future__ import annotations

import argparse
import sys

from .model import NX300State
from .shell import EmulatorShell


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Samsung NX300 behavioral emulator")
    p.add_argument("--scenario", choices=["boot", "hdmi-connected", "factory60"], default="boot")
    p.add_argument("--repl", action="store_true", help="start a local interactive emulator shell")
    p.add_argument("command", nargs=argparse.REMAINDER, help="single emulated command; place after --")
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    state = NX300State()
    state.apply_scenario(args.scenario)
    shell = EmulatorShell(state)
    if args.repl:
        while True:
            try:
                line = input("nx300-emu:/# ")
            except (EOFError, KeyboardInterrupt):
                print()
                return 0
            if line.strip() in {"exit", "quit"}:
                return 0
            code, output = shell.run(line)
            sys.stdout.write(output)
            if code:
                sys.stdout.write(f"[exit {code}]\n")
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser().print_help()
        return 0
    code, output = shell.run(" ".join(command))
    sys.stdout.write(output)
    return code


if __name__ == "__main__":
    raise SystemExit(main())

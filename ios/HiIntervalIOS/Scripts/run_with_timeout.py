#!/usr/bin/env python3
"""Run a command with a wall-clock limit and clean up its process group."""

import argparse
import os
import signal
import subprocess
import sys


GRACE_SECONDS = 2


class Interrupted(Exception):
    def __init__(self, signum: int) -> None:
        self.signum = signum


def _interrupt(signum: int, _frame: object) -> None:
    raise Interrupted(signum)


def _signal_group(pid: int, signum: int) -> None:
    try:
        os.killpg(pid, signum)
    except ProcessLookupError:
        pass


def _stop_group(process: subprocess.Popen[bytes]) -> None:
    # A command can exit while leaving children behind. Signal the entire group
    # even if the direct child has already exited.
    _signal_group(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        pass
    _signal_group(process.pid, signal.SIGKILL)
    process.wait()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("seconds", type=float, help="wall-clock limit in seconds")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="command and arguments")
    options = parser.parse_args(argv)
    if options.seconds <= 0 or not options.seconds < float("inf"):
        parser.error("seconds must be a finite positive number")
    command = options.command
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        parser.error("command is required")

    previous_handlers = {
        signum: signal.signal(signum, _interrupt)
        for signum in (signal.SIGINT, signal.SIGTERM)
    }
    process: subprocess.Popen[bytes] | None = None
    try:
        process = subprocess.Popen(command, start_new_session=True)
        try:
            return process.wait(timeout=options.seconds)
        except subprocess.TimeoutExpired:
            print(
                f"::error::Command exceeded {options.seconds:g}s wall-clock limit: "
                f"{command[0]}",
                file=sys.stderr,
                flush=True,
            )
            _stop_group(process)
            return 124
        except Interrupted as interruption:
            # Keep cleanup uninterrupted if another signal arrives during grace.
            for signum in previous_handlers:
                signal.signal(signum, signal.SIG_IGN)
            _stop_group(process)
            return 128 + interruption.signum
    except Interrupted as interruption:
        if process is not None:
            for signum in previous_handlers:
                signal.signal(signum, signal.SIG_IGN)
            _stop_group(process)
        return 128 + interruption.signum
    finally:
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


if len(sys.argv) != 3:
    raise SystemExit("usage: resolve_simulator.py <simctl-devices.json> <device-name>")

payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
requested_name = sys.argv[2]
candidates: list[tuple[tuple[int, ...], str]] = []

for runtime, devices in payload.get("devices", {}).items():
    version = tuple(int(part) for part in re.findall(r"\d+", runtime))
    for device in devices:
        if device.get("name") != requested_name or device.get("isAvailable") is False:
            continue
        if udid := device.get("udid"):
            candidates.append((version, udid))

if not candidates:
    raise SystemExit(f"Required simulator is unavailable: {requested_name}")

print(max(candidates)[1])

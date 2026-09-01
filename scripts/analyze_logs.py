#!/usr/bin/env python3
"""Turn a recent Mythic console window into a small incident signal report."""

from __future__ import annotations

import argparse
import json
import re
import sys


SIGNALS = {
    "crash": re.compile(r"watching server|crash report|serverhangwatchdog|encountered an unexpected exception", re.I),
    "stall": re.compile(r"can't keep up|server is overloaded|single server tick took", re.I),
    "disconnect": re.compile(r"lost connection|connection reset|disconnected", re.I),
    "content_error": re.compile(r"couldn't parse loot table|unknown item|failed to load datapack|parsing error", re.I),
    "player_event": re.compile(r"joined the game|left the game", re.I),
}


def analyze(text: str) -> dict[str, object]:
    lines = text.splitlines()
    counts: dict[str, int] = {name: 0 for name in SIGNALS}
    for line in lines:
        for name, pattern in SIGNALS.items():
            if pattern.search(line):
                counts[name] += 1
    return {
        "lines_scanned": len(lines),
        # Counts only. Raw log lines can contain credentials, player chat, or
        # other private data and never belong in doctor/snapshot JSON.
        "counts": counts,
    }


def self_test() -> int:
    sample = "\n".join([
        "Alice joined the game",
        "Can't keep up! Is the server overloaded?",
        "Alice lost connection: Timed out",
        "Couldn't parse loot table mythic:test",
        "ServerHangWatchdog: A single server tick took 60.00 seconds",
    ])
    got = analyze(sample)["counts"]
    expected = {"crash": 1, "stall": 2, "disconnect": 1, "content_error": 1, "player_event": 1}
    if got != expected:
        print(f"self-test failed: {got} != {expected}", file=sys.stderr)
        return 1
    print("analyze_logs self-test: pass")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    json.dump(analyze(sys.stdin.read()), sys.stdout, indent=2)
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

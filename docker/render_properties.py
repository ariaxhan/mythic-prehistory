#!/usr/bin/env python3
"""Merge managed keys into server.properties without disturbing anything else.

Three layers, lowest precedence first:

  1. the pack's own default-server.properties  (seeded once, on first boot)
  2. whatever is already in /data/server.properties (operator edits, and keys
     the pack's mods rewrite at runtime) -- PRESERVED
  3. keys this deployment manages          -- ALWAYS ENFORCED

Layer 3 is intentionally small. Gameplay-affecting settings the pack ships
(allow-nether, spawn-protection, max-tick-time, ...) are enforced at the value
the pack ships them at, never at a value of our own invention. `pvp` and
`difficulty` are deliberately absent so they stay at pack/vanilla defaults.
"""

from __future__ import annotations

import argparse
import sys


def read_properties(path: str) -> dict[str, str]:
    """Parse a .properties file. Missing file is an empty mapping, not an error."""
    values: dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if not line or line.startswith("#") or line.startswith("!"):
                    continue
                if "=" not in line:
                    continue
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip()
    except FileNotFoundError:
        pass
    return values


def write_properties(path: str, values: dict[str, str], header: str) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(f"# {header}\n")
        handle.write("# Managed keys are re-enforced on every boot; all other\n")
        handle.write("# keys are preserved as-is. See docker/render_properties.py.\n")
        for key in sorted(values):
            handle.write(f"{key}={values[key]}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current", required=True, help="live server.properties")
    parser.add_argument("--pack-defaults", required=True, help="pack default-server.properties")
    parser.add_argument("--out", required=True)
    parser.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                        help="managed key, always enforced")
    args = parser.parse_args()

    pack_defaults = read_properties(args.pack_defaults)
    current = read_properties(args.current)

    # Start from whatever is live: operator edits and mod-rewritten keys survive.
    merged: dict[str, str] = dict(current)

    # The handful of keys the pack explicitly ships are part of the official
    # pack configuration, so they are re-enforced every boot rather than merely
    # filling gaps -- otherwise an accidental edit could silently alter pack
    # behaviour (e.g. re-enabling the Nether) and never be noticed.
    merged.update(pack_defaults)

    # Our managed keys win outright.
    for item in args.set:
        if "=" not in item:
            print(f"invalid --set (expected KEY=VALUE): {item}", file=sys.stderr)
            return 1
        key, _, value = item.partition("=")
        merged[key.strip()] = value.strip()

    write_properties(args.out, merged, "Mythic Prehistory server.properties")
    return 0


if __name__ == "__main__":
    sys.exit(main())

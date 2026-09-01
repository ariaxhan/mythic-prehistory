#!/usr/bin/env python3
"""Fail closed on loot defects that otherwise void whole Minecraft tables."""

from __future__ import annotations

import json
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT.parent / "custom-mod" / "pack" / "datapacks" / "mythic-spawns"
ZIP = ROOT / "seed" / "config" / "paxi" / "datapacks" / "mythic-spawns.zip"
CATALOG = ROOT / "companion-mod" / "src" / "main" / "resources" / "mythic-loot-catalog.tsv"
REGISTRY = ROOT / "scripts" / "loot-live-registry.txt"

ALIASES = {
    "data/minecraft/loot_tables/jvs/fishing.json": "jvs:chest/fishing",
    "data/minecraft/loot_tables/jvs/interior.json": "jvs:chest/interior",
    "data/minecraft/loot_tables/jvs/exterior.json": "jvs:chest/exterior",
    "data/jvs/loot_tables/chest/fmob.json": "jvs:chest/mob",
}
REPAIRS = {
    "data/pelagic_prehistory/loot_tables/blocks/charnia.json",
    "data/pelagic_prehistory/loot_tables/blocks/ginkgo_leaves.json",
    "data/pelagic_prehistory/loot_tables/blocks/green_sea_sponge.json",
    "data/mansions/loot_tables/mansion_common.json",
    "data/strongholds/loot_tables/stronghold_equipment.json",
    "data/strongholds/loot_tables/stronghold_equipment_inline_1.json",
    "data/strongholds/loot_tables/stronghold_equipment_ranged.json",
    "data/strongholds/loot_tables/stronghold_equipment_ranged_inline_1.json",
    "data/simplyswords/loot_tables/grant_book_on_first_join.json",
}


def walk(value):
    yield value
    if isinstance(value, dict):
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def node_errors(value, source: str, proven_items: set[str]) -> list[str]:
    errors = []
    for node in walk(value):
        if not isinstance(node, dict):
            continue
        if node.get("condition") == "minecraft:alternative":
            errors.append(f"{source}: legacy condition minecraft:alternative")
        if node.get("type") == "minecraft:loot_table" and "value" in node:
            errors.append(f"{source}: 1.21 loot-table field value")
        if node.get("type") == "minecraft:item":
            item = node.get("name")
            if isinstance(item, str) and not item.startswith("minecraft:") and item not in proven_items:
                errors.append(f"{source}: item lacks live registry proof: {item}")
    return errors


def read_lines(path: Path) -> list[str]:
    return [line.strip() for line in path.read_text().splitlines() if line.strip() and not line.startswith("#")]


def catalog_errors(lines: list[str], proven_items: set[str]) -> list[str]:
    errors = []
    seen = set()
    tiers = set()
    for number, line in enumerate(lines, 1):
        parts = line.split("\t")
        if len(parts) != 3:
            errors.append(f"catalog line {number}: expected tier, weight, item")
            continue
        tier, weight, item = parts
        tiers.add(tier)
        if tier not in {"discovery", "rare", "jackpot"}:
            errors.append(f"catalog line {number}: invalid tier {tier}")
        if not weight.isdigit() or int(weight) < 1:
            errors.append(f"catalog line {number}: invalid weight {weight}")
        if item.startswith("minecraft:"):
            errors.append(f"catalog line {number}: vanilla filler forbidden: {item}")
        if item not in proven_items:
            errors.append(f"catalog line {number}: item lacks live registry proof: {item}")
        key = (tier, item)
        if key in seen:
            errors.append(f"catalog line {number}: duplicate {tier} item {item}")
        seen.add(key)
    if tiers != {"discovery", "rare", "jackpot"}:
        errors.append(f"catalog tiers incomplete: {sorted(tiers)}")
    return errors


def audit() -> list[str]:
    errors = []
    if not REGISTRY.is_file():
        return [f"missing live registry receipt: {REGISTRY}"]
    proven_items = set(read_lines(REGISTRY))

    vanilla_overrides = sorted((PACK / "data/minecraft/loot_tables/chests").glob("*.json"))
    if vanilla_overrides:
        errors.append(f"pack still replaces {len(vanilla_overrides)} vanilla chest tables instead of using centralized injection")

    source_files = sorted(path for path in PACK.rglob("*") if path.is_file() and path.name != ".DS_Store")
    for path in source_files:
        if path.suffix != ".json":
            continue
        relative = path.relative_to(PACK).as_posix()
        try:
            value = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{relative}: invalid JSON: {exc}")
            continue
        errors.extend(node_errors(value, relative, proven_items))

    for relative, target in ALIASES.items():
        path = PACK / relative
        if not path.is_file():
            errors.append(f"missing alias {relative} -> {target}")
            continue
        value = json.loads(path.read_text())
        names = [node.get("name") for node in walk(value) if isinstance(node, dict) and node.get("type") == "minecraft:loot_table"]
        if names != [target]:
            errors.append(f"wrong alias {relative}: expected only {target}, found {names}")

    for relative in sorted(REPAIRS):
        if not (PACK / relative).is_file():
            errors.append(f"missing shipped-mod repair: {relative}")

    if CATALOG.is_file():
        errors.extend(catalog_errors(read_lines(CATALOG), proven_items))
    else:
        errors.append(f"missing curated loot catalog: {CATALOG}")

    if not ZIP.is_file():
        errors.append(f"missing generated datapack: {ZIP}")
    else:
        with zipfile.ZipFile(ZIP) as archive:
            zipped = {name: archive.read(name) for name in archive.namelist() if not name.endswith("/") and not name.endswith(".DS_Store")}
        source = {path.relative_to(PACK).as_posix(): path.read_bytes() for path in source_files}
        if zipped != source:
            errors.append("generated datapack differs from canonical source")
    return errors


def self_test() -> None:
    proven = {"mod:good"}
    bad = {
        "condition": "minecraft:alternative",
        "entries": [
            {"type": "minecraft:item", "name": "mod:missing"},
            {"type": "minecraft:loot_table", "value": "mod:child"},
        ],
    }
    found = node_errors(bad, "fixture", proven)
    assert len(found) == 3, found
    assert catalog_errors(["discovery\t1\tminecraft:string"], proven)
    assert catalog_errors(["discovery\t1\tmod:missing"], proven)
    print("loot audit self-test: seeded defects detected")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        raise SystemExit(0)
    if sys.argv[1:]:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} [--self-test]")
    findings = audit()
    if findings:
        print("loot audit failed:", file=sys.stderr)
        for finding in findings:
            print(f"- {finding}", file=sys.stderr)
        raise SystemExit(1)
    print("loot audit passed")

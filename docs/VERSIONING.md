---
type: reference
status: active
created: 2026-08-31
updated: 2026-08-31
---

# Versioning and releases

Mythic Prehistory uses `MAJOR.MINOR.PATCH` versions and `vMAJOR.MINOR.PATCH` Git tags.

## What increments

| Increment | Use when | Examples |
|---|---|---|
| Major | Existing worlds or player data need an incompatible migration; Minecraft major/minor version changes | 1.20.1 → 1.21.x, intentional world reset |
| Minor | Compatible new gameplay, mods, bosses, structures, progression, or player action | Eight-mod difficulty expansion, new bootstrap import |
| Patch | Compatible fixes, balance, configuration, documentation, or performance changes | Loot-table repair, crash fix, tuning adjustment |

Pre-release candidates use `v1.4.0-rc.1`. Stable releases never reuse or move a tag.

## Sources of truth

1. `pack.env`: runtime/build version and asserted mod counts.
2. `CHANGELOG.md`: player-visible contents, migration, verification, and known limitations.
3. Public Git tag and GitHub Release: immutable release marker and shareable notes.
4. Published Packwiz `pack.toml`: version clients actually receive.
5. Live `/data/.dc/pack-version`: version the server actually seeded.

These values must agree before a release is called complete. A commit, tag, uploaded client manifest, deployed image, and live READY server are separate states.

## Coordinated release sequence

Client/server mod changes require an empty maintenance window because either side updating alone can reject joins.

1. Confirm `./mpctl doctor` reports `MAINTENANCE` or `OFFLINE`.
2. Bump `PACK_VERSION`, `PACK_DISPLAY`, and mod-count assertions in `pack.env`.
3. Move `[Unreleased]` entries into a dated changelog section.
4. Run `scripts/check-version.sh`, client-pack tests, companion-mod tests, and configured live-ops checks.
5. Create and verify a world backup before server mutation.
6. Build/deploy the server image while it remains unavailable to players.
7. Publish the client pack; upload versioned objects first and `pack.toml` last.
8. Start the server and prove READY, matching live pack version, mod counts, logs, and TPS.
9. Publish the sanitized public-repository snapshot.
10. Tag the exact public commit `vX.Y.Z`, push the tag, and create the GitHub Release from that changelog section.
11. Perform a clean client update, second idempotent launch, and real join test.

If any verification fails, do not move the tag. Repair the release or increment the version.

## Changelog rules

- Write for players first: additions, changes, fixes, migration, and known limitations.
- Name exact mod versions and counts when they changed.
- Separate shipped behavior from verification still owed.
- Never claim existing terrain was retrofitted when a mod only affects new chunks.
- Never call per-player loot proven without a two-player acceptance test.
- Keep `[Unreleased]` at the top once post-1.3 work begins.

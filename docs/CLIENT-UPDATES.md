---
type: reference
status: active
created: 2026-08-31
updated: 2026-08-31
---

# Automatic client updates

Mythic uses Packwiz through Prism's pre-launch command. A player imports the bootstrap
zip once. Every later launch checks `pack.toml`, verifies hashes, downloads changed
files, removes obsolete managed files, then starts Forge.

Managed: mods and `minecraft/config/`. Preserved: `options.txt`, servers, saves,
screenshots, logs, Xaero maps, and other player-created data.

## Release

```bash
scripts/build-client-pack.sh
scripts/test-client-pack.sh
scripts/publish-client-pack.sh
scripts/export-client-bootstrap.sh https://mythic-pack.ariaxhan.com/pack.toml
```

Publish `.cache/client-pack-site/` atomically: upload versioned files first and
`pack.toml` last. Never publish a manifest before every referenced file is reachable.
The public files live in the `mythic-prehistory-pack` R2 bucket and are served by
the read-only Worker in `client-pack-host/`.

New players import:

`https://mythic-pack.ariaxhan.com/downloads/MythicPrehistory-client.zip`

## Rollback

Restore the prior site snapshot, again replacing `pack.toml` last. The next launch
converges clients to that manifest. Server rollback remains `scripts/rollback.sh`.

## Failure behavior

An unavailable or corrupt update stops before Minecraft. Do not bypass it: report the
updater error. The operator restores hosting or rolls back the manifest.

# Mythic Prehistory project map

This is a Forge 1.20.1 modpack and a single Fly.io Minecraft server. The
repository owns the server image, pack seed, operator tooling, client handoff
docs, and selected client configuration. The persistent Fly volume owns the
actual world.

## Control path

`mpctl` is the human and agent entrypoint. It talks to Fly Machines for lifecycle,
the authenticated `/status` and `/logs` endpoints for cheap observation, and
localhost-only RCON through `fly ssh` for Minecraft commands. `scripts/deploy.sh`
is the only normal deploy path and refuses to deploy over connected players.

The container starts through `docker/entrypoint.sh`, which reconciles pack-owned
configuration onto `/data`, then runs `docker/supervisor.sh`. The supervisor
preserves console/crash evidence and bounds crash restarts. `idle_monitor.sh`
stops an empty server after the configured window; `shutdown.sh` saves and backs
up before halt. Backups live on the volume and can also copy to R2.

## Source ownership

| Surface | Durable source | Live location / evidence |
|---|---|---|
| Server properties | `seed/default-server.properties` plus entrypoint reconciliation | `/data/server.properties` |
| Forge/mod config | `seed/config/`; entrypoint overlays it only when `PACK_VERSION` changes | `/data/config/`; config-only releases need a version bump or a deliberate live copy plus reload/restart |
| New-world defaults | `seed/defaultconfigs/` | copied into a world's serverconfig |
| Existing-world server config | seed counterpart plus deliberate live edit | `/data/world/serverconfig/` |
| Datapacks and quests | Paxi/FTB files below `seed/config/` | live registry, `reload`, RCON probes |
| Mods and JVM/runtime code | `mods/`, `Dockerfile`, `docker/` | deployed image and fresh boot |
| Gamerules and player state | world itself | RCON, `level.dat`, playerdata |
| Client behavior | Prism instance and shipped client pack | client `latest.log`, crash reports, rendered UI |

## Failure history that changes operations

- Teleports into ungenerated Terralith/Tectonic terrain blocked the server
  thread. The vanilla hang watchdog converted recoverable stalls into crash
  loops. Terrain is pregenerated, `/rtp` and gateways are capped to 3000, async
  chunk writes are enabled, and the supervisor owns crash-loop protection.
- A single unregistered item ID or wrong-version loot-table field invalidated an
  entire table, producing empty Lootr chests. Item language keys are not registry
  proof. Bulk registry checks are reserved for an empty server.
- World regeneration reset `keepInventory`; it is world state, not pack config.
- Legendary Survival Overhaul COMMON config was changed server-side but remained
  active on the client. COMMON does not imply synchronized.
- A committed JVM/config change was once assumed live after a failed deploy.
  Fresh READY plus runtime evidence is required after every image change.
- Session-bound pregeneration and billing watchers nearly stranded the machine
  running. Long jobs and their fail-open billing backstops must live with the
  server, not in an agent terminal.

## First five minutes

1. Read `.agents/skills/mythic-live-ops/SKILL.md`.
2. Run `./mpctl doctor` and obey the reported mode.
3. Use `./mpctl snapshot` for a before receipt.
4. Match the symptom time against the narrowest server or client log window.
5. Identify both the live owner and durable owner before changing anything.

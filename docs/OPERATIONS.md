# Mythic Prehistory operations

`./mpctl doctor` is the front door. It reports one of four occupancy modes and
summarizes current log signals. The mode is an action ceiling, not advice.

| Mode | Meaning | Safe ceiling |
|---|---|---|
| PLAYING | At least one player is connected | Read-only probes and bounded reversible RCON |
| MAINTENANCE | Server is ready and empty | Backups, restarts, deploys, pregen, heavier checks |
| OFFLINE | Fly machine compute is stopped | Repo/client work; start to make live claims |
| UNKNOWN | Occupancy cannot be proven | Read-only only |

## The six owners

Most wasted time came from editing the right-looking file on the wrong side.
Classify first: client config, server runtime, world state, world/serverconfig,
pack seed, or deployed image. A fix often needs two writes: the live owner for
relief and the durable owner so restart or redeploy does not erase it.

Examples from this pack:

- `keepInventory` is world state in `level.dat`; world regeneration resets it.
- FTB Essentials `/rtp` is world/serverconfig and loads with the world.
- Legendary Survival Overhaul COMMON config exists independently on client and
  server; changing the server did not remove the client's HUD or behavior.
- `sync-chunk-writes` is reconciled from the pack seed on boot, so a live-only
  edit reverts.
- JVM flags and bundled mods are image-owned and are not live until deploy plus
  a fresh READY boot.

## Play-session method

Anchor every report to a time and player action, then inspect the smallest log
window around it. Preserve play unless evidence demands interruption. Do not run
wide RCON loops, terrain generation, deploys, or restarts around connected
players. If the durable repair is restart-bound, apply only proven reversible
relief and queue the durable half for the empty-server window.

`./mpctl console --live-safe "<reason>" <command>` is the narrow relief lane.
While players are connected it accepts only bounded `effect` and `give`
commands. Teleports, terrain work, gamerule changes, and arbitrary RCON wait for
maintenance.

## Maintenance method

With zero players: preserve evidence, reproduce from logs or a controlled probe,
fix the failure class, update every persistence sibling, run the checks listed in
`ops/live-ops.yaml`, deploy through `scripts/deploy.sh`, and verify the actual
fresh runtime. A commit is not a deploy and a deploy is not proof of behavior.

## Incident receipt

`./mpctl snapshot` prints a secret-free Markdown receipt with timestamp, git
state, occupancy mode, status, and log-signal counts. Put it in the session
chronicle before and after a material fix. Add the symptom, diagnosis, exact
mutation, rollback, and live verification evidence between those snapshots.

# Pokémon mod feasibility for Mythic Prehistory

## Recommendation

Use **Cobblemon 1.5.2 for Forge 1.20.1** if the goal is Pokémon living alongside
Mythic Prehistory. Do not use Pixelmon 9.2.3 unless the pack is deliberately
rebuilt around it.

Cobblemon is a moderate integration. A rough prototype is one focused evening;
a production-quality addition is about four to eight hours of compatibility,
spawn-balance, client-pack, and live verification work. No world wipe should be
required.

## Why Cobblemon fits

- The official 1.20.1 Forge build is 1.5.2. It requires Kotlin for Forge, which
  Mythic already ships.
- Cobblemon is designed to coexist with broader Minecraft modpacks rather than
  replace the entire game loop.
- It is required on both server and every client. The safe change is therefore
  one server image update plus synchronized updates to both Prism instances and
  the friend handoff pack.
- Mythic already has the right loader family, Minecraft version, Java version,
  and several common ecosystem libraries.

Official sources: [Cobblemon versions on Modrinth](https://modrinth.com/mod/cobblemon/versions?g=1.20.1),
[Cobblemon project/install details](https://modrinth.com/mod/cobblemon), and the
[legacy Forge 1.20.1 site](https://legacy.cobblemon.com/).

## What actually makes it work

The jar is the easy part. Before production, an isolated copy needs to prove:

1. Cobblemon 1.5.2 loads beside Mythic's current Kotlin for Forge 4.12.0 and all
   125 client mods.
2. Both a headless server and the real Prism client reach the menu/READY with no
   mixin, registry, rendering, or keybind failures.
3. Pokémon spawning does not overwhelm the existing In Control dinosaur caps or
   push entity/tick load back into the old stall regime.
4. Terralith/Tectonic and the already-pregenerated 3000-block region still give
   sensible Pokémon habitats. Any Cobblemon worldgen content may require travel
   beyond existing chunks or a deliberate retrogen strategy.
5. Capture, battle, fainting, death, teleporting, Waystones, dimensions, Lootr,
   backpacks, and multiplayer reconnects work in a disposable world copy.
6. The client bundle, mod-count gates, server image, manual, and rollback receipt
   all update together.

## Why not Pixelmon here

Pixelmon 9.2.3 technically targets Minecraft 1.20.1, but it is an old alpha from
October 2023. Pixelmon now says the 1.20.1 line is unsupported and receives no
fixes. Its official incompatibility list specifically warns that Waystones can
lock the game when teleporting with a Pokémon sent out. Mythic relies on
Waystones and already has a history of teleport-related stalls.

Official sources: [Pixelmon installation/version table](https://pixelmonmod.com/wiki/Installation),
[1.20.1 version history](https://pixelmonmod.com/wiki/Version_history/1.20.1),
[server version requirements](https://pixelmonmod.com/wiki/Server_installation),
and [Pixelmon's incompatibility list](https://pixelmonmod.com/wiki/Incompatibilities_list).

## Effort estimate

| Scope | Estimate | Result |
|---|---:|---|
| Disposable compatibility boot | 1-2 hours | Know whether Cobblemon loads cleanly |
| Playable test pack | 2-4 hours | Both clients join; basic capture/battle works |
| Mythic-quality integration | 4-8 hours total | Spawn tuning, docs, client handoff, rollback, live verification |
| Pixelmon integration | 1-3 days, high risk | Old unsupported alpha plus likely Waystones redesign |

The safest next move is a disposable Cobblemon 1.5.2 branch and cloned test
world. The live server currently has two players and must not be restarted or
deployed for this experiment.


---
type: reference
status: active
created: 2026-08-30
updated: 2026-08-31
---

# Locally pinned mod artifacts

`mods/` is intentionally ignored. These pins reconstruct the artifacts changed by pack `1.0.1`.

Pack `1.1.0` disables Canary 0.3.3 on both sides. ModernFix already owns the overlapping
chunk-ticket optimization; running both produced a mixin overwrite conflict on every boot.

| Artifact | SHA-512 | Source |
| --- | --- | --- |
| `jei-1.20.1-forge-15.56.0.204.jar` | `50432dbea3587679c89f0ebd4e2f4d160ec14a8f2005cb24b2a7c8264d25e0fffcb523b6facd70d349ae585a171a1c2bf4ab7ce27c2694122a7daf8b5c98d50e` | `https://cdn.modrinth.com/data/u6dRKJwZ/versions/iGfgvBU7/jei-1.20.1-forge-15.56.0.204.jar` |
| `sophisticatedcore-1.20.1-1.3.84.2308.jar` | `f287c44700f38673e8691ca07a24ab579bcd72ce596950cbeb2d2566fda00069f7535c8deac06ae05bc92cba3efc75427822b7e3aacfdd6f166b18a3dc24d40e` | `https://cdn.modrinth.com/data/nmoqTijg/versions/JGT2DD0v/sophisticatedcore-1.20.1-1.3.84.2308.jar` |
| `sophisticatedbackpacks-1.20.1-3.24.67.2109.jar` | `11c2e8084686d3a2bd9c94a4a7d0a52773adc6ebd2ba0b28bba05975862240a57dc48e83b92029e266de3bcb2214d7a5dd8c1c9bdd314b6863eb8cbe1cff9c1b` | `https://cdn.modrinth.com/data/TyCTlI4b/versions/as0tf712/sophisticatedbackpacks-1.20.1-3.24.67.2109.jar` |
| `sophisticatedstorage-1.20.1-1.4.86.2131.jar` | `c3698fd39af033e6bdcd80e7eb194a2d284ab1f026a095b22d3c99838fd01fb6f8b6ae855b7baa6d9b1509ea130565d18b22bdd31a9d1de41b014ea50ddbb001` | `https://cdn.modrinth.com/data/hMlaZH8f/versions/JCxeJIsN/sophisticatedstorage-1.20.1-1.4.86.2131.jar` |
| `xaeroworldmap-forge-1.20.1-1.45.0.jar` | `c874f83bfca4d4de1b403f07674adaf8079c07f3e41cb78e7f968301a022480d225144267decf8c75affa92ea7a66d6100263b7732829bb80639d3bb499fc587` | `https://cdn.modrinth.com/data/NcUtCpym/versions/3fGuLVo4/xaeroworldmap-forge-1.20.1-1.45.0.jar` |
| `packetfixer-3.3.2-1.18-1.20.4-merged.jar` | `916501acefab2a33f7b5438375dec0c3d523975d82c807c98496227c107c1efd57c95d9e1501d657513324a9ad617eb8ef7e963921263389af896da55dc707a9` | `https://cdn.modrinth.com/data/c7m1mi73/versions/9F4NGhGR/packetfixer-3.3.2-1.18-1.20.4-merged.jar` |

Macu Lib stays on upstream `1.0.6`; `scripts/patch-macu-supporters-url.sh` replaces its dead supporter-list URL. Patched SHA-256: `a258b0446a7b0c207ad0381036ce0a3f23eb18ec4244cc82f8e35227138eac49`.

Pack `1.3.0` adds the difficulty expansion. Its eight server/client artifacts and
SHA-512 pins live in `expansion-mods.lock.tsv`; `scripts/download-expansion-mods.sh`
is the single installer used by local verification and the server image build.

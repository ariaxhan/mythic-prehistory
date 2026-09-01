# Changelog

All player-visible Mythic Prehistory releases are recorded here. Versions follow [Semantic Versioning](docs/VERSIONING.md).

## [Unreleased]

### Changed

- Every Mythic-bonded prehistoric companion can be commanded to sit with an empty-hand sneak-right-click. Sitting persists through relogs, freezes movement every tick, and disables following and defense until released.

## [1.3.0] - 2026-08-31

Difficulty expansion, new bosses and dungeons, stronger hostile mobs, repaired high-tier rewards, and the first public automatic-update release.

### Added

- **Meet Your Fight 1.6.1:** four boss encounters: Bellringer, Dame Fortuna, Swampjaw, and Rosalyne.
- **Mowzie's Mobs 1.8.2:** Frostmaw, Ferrous Wroughtnaut, Umvuthi, the Sculptor challenge, and the mod's wider creature/content set.
- **Dimensional Dungeons 207:** portal-accessed dungeon runs in dedicated dimensions, separating dungeon destruction from the overworld.
- **Majrusz's Progressive Difficulty 1.9.10:** world difficulty escalates as progression advances; Majrusz Library 7.0.8 added as its dependency.
- **Champions Unofficial 2.1.12.7:** supported hostile mobs can become stronger affixed champions with improved rewards.
- **Trading Post 8.0.2:** craftable village trading interface that gathers nearby villager offers into one screen.
- **Polymorph 0.49.10:** recipe-selection UI for crafting conflicts between mods.
- Eight FTB Quests in **Trials of the Titans**: one for each Meet Your Fight boss and four major Mowzie encounters.
- Each new boss quest grants one claim from the high-tier **Titan's Hoard** reward table through FTB Quests, separate from shared world drops.

### Changed

- Client mod count increased from 128 to 136; server mod count increased from 113 to 121.
- Expansion artifacts are pinned by SHA-512 and reconstructed from `expansion-mods.lock.tsv` instead of committing third-party jars.
- The automatic client updater is now publicly hosted on Cloudflare R2 at `mythic-pack.ariaxhan.com`.
- The Prism bootstrap is public and small; first launch installs the complete hash-verified pack, and later launches download only approved changes.
- Managed client files are mods and pack configuration. Saves, screenshots, options, server list, Xaero maps, and other player data remain untouched.
- Windows migration now uses a clean side-by-side Prism instance instead of overwriting the old pack.

### Rewards and flight

- Replaced the nonexistent `recased:special_loot_case` in **Titan's Hoard** with valid weapon and armor loot cases. The invalid ID previously risked voiding the reward table.
- Removed `losttrinkets:magical_feathers` from **Relics of the Old World** and replaced it with `losttrinkets:minds_eye`.
- Blacklisted Magical Feathers from random Lost Trinkets unlocks, preventing new creative-flight unlocks through the normal pack path.
- Trading Post remains craftable; the recipe was not removed or made operator-only.

### Fixed and hardened

- Corrected escaped quoting in the Prism pre-launch command. The original bootstrap could make Windows Prism concatenate `javaw.exe` and `-jar`, preventing the updater from starting.
- Selected Champions 2.1.12.7 after 2.1.10.2 crashed dedicated Forge without KubeJS.
- Fixed the Docker build context so the expansion downloader is included in server images.
- Fixed expansion validation to check the eight lock-listed artifacts rather than comparing them with the complete 121-jar server directory.
- Client publication uploads and verifies all versioned objects before replacing `pack.toml`, preventing clients from seeing a half-published release.
- Public pack hosting is read-only and returns bounded GET/HEAD/404/405 responses.

### Server verification

- Preserved the existing world behind two verified pre-deploy backups, both uploaded off-site.
- Live server booted pack 1.3.0 with all 121 server jars and 147 FTB quests.
- Empty-server verification reported 20.000 TPS, 1.566 ms overall mean tick time, 2.9 GB JVM RSS, and no crash, stall, disconnect, or content-error signals.
- Durable tuning remained: 6 GB heap, view distance 8, simulation distance 6, asynchronous chunk writes, and disabled watchdog timeout for heavy modded world generation.

### Player action required

- Existing players must import the new `MythicPrehistory-client.zip` bootstrap as a clean Prism instance once.
- Do not update individual mods. Packwiz synchronizes the approved set before every launch.
- Keep the old instance until the new one reaches the menu twice and successfully joins the server.

### Known limitations

- Trading Posts are **not** automatically placed in existing or future villages yet. The block is available and craftable.
- All eight new boss quests currently draw from the same Titan's Hoard table; boss-specific reward identities remain future work.
- The new boss reward path is implemented through FTB Quests, but a two-player personal-claim acceptance test is still outstanding.
- Blacklisting Magical Feathers prevents new unlocks but does not revoke the trinket from a player who had already unlocked it before 1.3.0.
- New structures and terrain-dependent content appear in unexplored chunks or their dedicated dimensions; existing generated terrain is not rewritten.

## [1.2.0] - 2026-08-31

Previous release and comparison baseline for 1.3.0.

### Added

- Packwiz-based automatic client-update pipeline and Prism pre-launch bootstrap.
- Hash verification, idempotent updates, managed-file removal, and corruption repair tests.
- Packet Fixer 3.3.2 for Immersive Furniture's required networking compatibility.

### Changed

- Client mod count increased from 127 to 128; server mod count increased from 112 to 113.
- Pack-owned mods and configuration became updater-managed while personal Prism data remained preserved.

[1.3.0]: https://github.com/ariaxhan/mythic-prehistory/releases/tag/v1.3.0
[1.2.0]: CHANGELOG.md#120---2026-08-31

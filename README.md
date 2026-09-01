# Mythic Prehistory

Minecraft 1.20.1 Forge modpack, dedicated-server image, automatic client updater, and player documentation.

- [Changelog](CHANGELOG.md)
- [Versioning and release policy](docs/VERSIONING.md)

## Players

- [Windows migration and troubleshooting guide](docs/JOIN-WINDOWS.md)
- [Download the Prism bootstrap](https://mythic-pack.ariaxhan.com/downloads/MythicPrehistory-client.zip)
- Server: `aria-mythic-prehistory.fly.dev`

The bootstrap installs the approved pack and checks for updates before every launch. Do not install or update individual mods.

## Repository contents

- `docs/`: player and operator guides
- `client-pack/`: Packwiz metadata for pinned client dependencies
- `companion-mod/`: Mythic's custom Forge mod source
- `docker/`, `scripts/`, `ops/`: server image and operations tooling
- `seed/`: versioned server and pack configuration

Third-party mod jars, worlds, backups, credentials, and player data are not included. Mod files are resolved from their pinned upstream sources during authorized builds.

## Versions

- Mythic Prehistory 1.3.1
- Minecraft 1.20.1
- Forge 47.4.22
- Java 17

# =============================================================================
# Mythic Prehistory dedicated server -- Minecraft 1.20.1 / Forge 47.4.22
#
# Java 17 is REQUIRED: 1.20.1 targets 17, and the Prism instance this pack was
# authored and tested in runs 17.0.15. Do not bump without re-testing the pack.
#
# Layout contract (same as deceasedcraft/, which this rig is adapted from):
#   /opt/mc   immutable pack + Forge install, baked into the image
#   /data     the Fly volume; ALL runtime-mutated state lives here
#
# Unlike deceasedcraft/, there is no upstream pack zip to download and hash.
# This is our own pack: the ignored local mods/ directory comes from Prism,
# while repo-added server mods are downloaded and hash-pinned below. The
# integrity gate asserts the final count.
#
# Built for linux/amd64. Deploys use Fly's remote builder, so this is never
# cross-compiled or emulated from an arm64 workstation.
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: build the pack-owned companion mod from pinned source and tooling.
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk-jammy AS companion_build

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl unzip; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src/companion-mod
COPY companion-mod/ ./
RUN set -eux; \
    ./gradlew --no-daemon clean test build; \
    test -f build/libs/mythic-companions-1.2.1.jar

# -----------------------------------------------------------------------------
# Stage 2: install the Forge dedicated server, then lay our pack over it.
# A JDK (not JRE) is used because the Forge installer runs jar-processing steps
# that expect a full JDK.
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jdk-jammy AS build

ARG MINECRAFT_VERSION
ARG FORGE_VERSION
ARG FORGE_INSTALLER_URL
ARG SERVER_MOD_COUNT
ARG MINE_SPAWNERS_URL="https://cdn.modrinth.com/data/7VESbzyX/versions/hDUuG3QZ/mine_spawners_forge-1.1.jar"
ARG MINE_SPAWNERS_SHA1="b9a6e214d6a5766dbe91db00f75bdfe0966d8270"
ARG PACKET_FIXER_URL="https://cdn.modrinth.com/data/c7m1mi73/versions/9F4NGhGR/packetfixer-3.3.2-1.18-1.20.4-merged.jar"
ARG PACKET_FIXER_SHA512="916501acefab2a33f7b5438375dec0c3d523975d82c807c98496227c107c1efd57c95d9e1501d657513324a9ad617eb8ef7e963921263389af896da55dc707a9"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/mc

# Install the Forge dedicated server. This pulls the vanilla server jar and
# Forge libraries from Mojang/Forge maven into /opt/mc/libraries.
RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 5 -o /tmp/forge-installer.jar "${FORGE_INSTALLER_URL}"; \
    java -jar /tmp/forge-installer.jar --installServer /opt/mc; \
    test -f "/opt/mc/libraries/net/minecraftforge/forge/${MINECRAFT_VERSION}-${FORGE_VERSION}/unix_args.txt" \
      || { echo "FATAL: forge unix_args.txt not produced -- install failed"; exit 1; }; \
    rm -f /tmp/forge-installer.jar /opt/mc/*installer*.jar /opt/mc/*installer*.log

# Server-side mod jars. Client-only mods (rendering, HUD, input, tooltip UI)
# were excluded when this directory was built -- see CLIENT_ONLY.txt. Shipping
# one of those here is a boot crash, not a warning.
COPY mods/ /opt/mc/mods/

# Pack-owned source mod. Both server and clients require this same jar.
COPY --from=companion_build \
    /src/companion-mod/build/libs/mythic-companions-1.2.1.jar \
    /opt/mc/mods/mythic-companions-1.2.1.jar

# Server-only, GPL-3.0: Silk Touch pickaxes can relocate spawners while
# preserving mob data. Pin the artifact so rebuilding Prism's ignored mods/
# directory cannot silently remove or replace this pack-owned addition.
RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 5 \
      -o /opt/mc/mods/mine_spawners_forge-1.1.jar "${MINE_SPAWNERS_URL}"; \
    echo "${MINE_SPAWNERS_SHA1}  /opt/mc/mods/mine_spawners_forge-1.1.jar" \
      | sha1sum -c -

# Both sides: Immersive Furniture transfers large furniture definitions and
# explicitly requires Packet Fixer. Hash-pin the same artifact used by clients.
RUN set -eux; \
    curl -fsSL --retry 5 --retry-delay 5 \
      -o /opt/mc/mods/packetfixer-3.3.2-1.18-1.20.4-merged.jar "${PACKET_FIXER_URL}"; \
    echo "${PACKET_FIXER_SHA512}  /opt/mc/mods/packetfixer-3.3.2-1.18-1.20.4-merged.jar" \
      | sha512sum -c -

# Pack-owned expansion. One manifest drives both local verification and image
# assembly; every network artifact is SHA-512 pinned.
COPY expansion-mods.lock.tsv /opt/mp-build/expansion-mods.lock.tsv
COPY scripts/download-expansion-mods.sh /opt/mp-build/download-expansion-mods.sh
RUN set -eux; \
    chmod +x /opt/mp-build/download-expansion-mods.sh; \
    EXPANSION_MODS_LOCK=/opt/mp-build/expansion-mods.lock.tsv \
      /opt/mp-build/download-expansion-mods.sh /opt/mc/mods

# Fail the build rather than ship a partial pack.
RUN set -eux; \
    mods="$(find /opt/mc/mods -name '*.jar' | wc -l)"; \
    echo "server mod jars: ${mods}"; \
    test "${mods}" -eq "${SERVER_MOD_COUNT}" \
      || { echo "FATAL: expected ${SERVER_MOD_COUNT} mod jars, found ${mods}"; exit 1; }

# SEED copies of pack content. The entrypoint installs these onto the volume on
# first boot, where mods are then free to rewrite them. Includes the FTB Quests
# book, which is pack content rather than user state.
COPY seed/ /opt/mc/seed/

RUN set -eux; \
    test -d /opt/mc/seed/config || { echo "FATAL: seed/config missing"; exit 1; }; \
    echo "seed config files: $(find /opt/mc/seed/config -type f | wc -l)"

# -----------------------------------------------------------------------------
# Stage 3: runtime. JRE only -- no compiler, no build tooling.
# -----------------------------------------------------------------------------
FROM eclipse-temurin:17-jre-jammy AS runtime

# tini    -- correct PID 1 signal handling so SIGTERM reaches our shutdown path
# python3 -- status server + RCON client (stdlib only) and boto3 for R2 backups
# procps  -- /proc-based cpu+memory sampling for the status endpoint
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash ca-certificates curl tini procps tar zstd \
        python3 python3-pip; \
    pip3 install --no-cache-dir 'boto3==1.34.162'; \
    apt-get purge -y python3-pip; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/mc /opt/mc

# Operational scripts. Kept out of /data so the volume holds only game state.
COPY docker/ /opt/mp/
RUN chmod +x /opt/mp/*.sh /opt/mp/*.py

# Pinned release metadata, readable at runtime by the status endpoint so the
# reported version can never drift from what was actually built.
COPY pack.env /opt/mp/pack.env

ENV MC_DIR=/data \
    MC_HOME=/opt/mc \
    DC_BIN=/opt/mp \
    MC_HEAP=6G \
    MC_PORT=25565 \
    STATUS_PORT=8080 \
    RCON_PORT=25575 \
    IDLE_SHUTDOWN_MINUTES=20 \
    BACKUP_INTERVAL_MINUTES=60 \
    BACKUP_LOCAL_KEEP=2 \
    R2_KEEP=2 \
    MAX_CRASH_RESTARTS=3 \
    R2_PREFIX=mythic-prehistory \
    PYTHONUNBUFFERED=1

WORKDIR /data

# 25565 Minecraft (public). 8080 status (public, token-gated).
# 25575 RCON is deliberately NOT exposed here and not published in fly.toml.
EXPOSE 25565 8080

# NOTE: deliberately NOT `tini -g`. Process-group signalling would deliver
# SIGINT straight to the JVM in parallel with our shutdown script, so Java would
# begin dying while the pre-shutdown backup was still archiving the world. Only
# the direct child is signalled; shutdown.sh then owns the JVM's lifecycle and
# stops it over RCON once the backup is safely on disk.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/opt/mp/entrypoint.sh"]

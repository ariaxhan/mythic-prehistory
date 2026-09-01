#!/usr/bin/env bash
# PID-1 payload. Prepares the volume, starts the status server and idle monitor,
# then hands off to the supervisor which owns the Java process.
#
# Exit code contract: this script exits 0 for every *intended* stop (idle
# shutdown, operator stop, crash-loop giveup). Fly's restart policy is
# on-failure, so exiting 0 means "the machine should stay stopped".

set -euo pipefail

DC_COMPONENT="entrypoint"
# shellcheck source=lib.sh
source /opt/mp/lib.sh
# shellcheck source=/opt/mp/pack.env
source /opt/mp/pack.env

require_env MC_DIR MC_HOME MC_HEAP MC_PORT STATUS_PORT RCON_PORT \
            IDLE_SHUTDOWN_MINUTES MAX_CRASH_RESTARTS \
            VIEW_DISTANCE SIMULATION_DISTANCE MAX_PLAYERS

# Whitelist is off for now so both players can join without pre-registration.
# online-mode stays true regardless, so every account is still authenticated
# against Mojang. Flip WHITELIST_ENABLED to "true" in fly.toml to close it.
WHITELIST_ENABLED="${WHITELIST_ENABLED:-false}"

log "Mythic Prehistory ${PACK_VERSION} | Minecraft ${MINECRAFT_VERSION} | Forge ${FORGE_VERSION}"

# --- 0. The volume must actually be mounted ----------------------------------
# A missing mount would silently write the world into the container's ephemeral
# layer and lose it on the next deploy. That is the single worst failure mode
# here, so it is checked first and fatally.
if ! mountpoint -q "${MC_DIR}" 2>/dev/null; then
  # mountpoint is unavailable in some minimal images; fall back to /proc.
  if ! grep -qE "[[:space:]]${MC_DIR}[[:space:]]" /proc/mounts; then
    die "${MC_DIR} is not a mount point -- the Fly volume is not attached. Refusing to start, because the world would be written to disposable storage."
  fi
fi
log "volume mounted at ${MC_DIR} ($(df -h "${MC_DIR}" | awk 'NR==2 {print $4" free of "$2}'))"

mkdir -p "${DC_STATE}" "${DC_BACKUPS}" "${MC_DIR}/logs" "${MC_DIR}/crash-reports"
rm -f "${READY_FLAG}" "${STOPPING_FLAG}"

# --- 1. Immutable pack content, served from the image -------------------------
# mods/ and libraries/ are byte-identical to what the image was built with and
# are never mutated at runtime, so they are symlinks rather than copies. This
# keeps ~290 MB off the volume and guarantees a deploy can never leave a stale
# mod jar behind.
link_from_image() {
  local name="$1"
  local target="${MC_HOME}/${name}"
  local link="${MC_DIR}/${name}"
  [[ -d "${target}" ]] || die "image is missing ${target}"
  if [[ -L "${link}" ]]; then
    ln -sfn "${target}" "${link}"
  elif [[ -e "${link}" ]]; then
    # A real directory here is left over from an older layout. Move it aside
    # rather than deleting -- never destroy data we did not create this run.
    log "WARN: ${link} is a real directory, not a symlink; archiving it"
    mv "${link}" "${link}.replaced-$(date -u '+%Y%m%dT%H%M%SZ')"
    ln -s "${target}" "${link}"
  else
    ln -s "${target}" "${link}"
  fi
}
link_from_image mods
link_from_image libraries

# --- 2. Mutable pack content, seeded onto the volume --------------------------
# These directories ARE rewritten at runtime by mods, so they must live on the
# volume. They are re-seeded only when the pinned pack version changes, and the
# previous copies are archived first so an update is always reversible.
PACK_MARKER="${DC_STATE}/pack-version"
INSTALLED_PACK="$(cat "${PACK_MARKER}" 2>/dev/null || true)"
# Mythic Prehistory ships config/ and defaultconfigs/ only. DeceasedCraft also
# seeded kubejs/, scripts/ and resources/ because that pack is KubeJS-driven;
# ours is not, and requiring empty directories here would just be ceremony that
# fails the boot when one is absent.
SEED_DIRS=(config defaultconfigs)

if [[ "${INSTALLED_PACK}" != "${PACK_VERSION}" ]]; then
  if [[ -n "${INSTALLED_PACK}" ]]; then
    log "pack version change: ${INSTALLED_PACK} -> ${PACK_VERSION}; archiving current configs"
    archive="${DC_BACKUPS}/configs-pre-${PACK_VERSION}-$(date -u '+%Y%m%dT%H%M%SZ').tar.zst"
    tar -C "${MC_DIR}" -I 'zstd -3' -cf "${archive}" \
        $(for d in "${SEED_DIRS[@]}"; do [[ -d "${MC_DIR}/${d}" ]] && printf '%s ' "${d}"; done) \
      || die "failed to archive existing configs before re-seed"
    log "archived to ${archive}"
  else
    log "first boot: seeding pack ${PACK_VERSION} onto the volume"
  fi

  for d in "${SEED_DIRS[@]}"; do
    src="${MC_HOME}/seed/${d}"
    [[ -d "${src}" ]] || die "image is missing seed directory ${src}"
    mkdir -p "${MC_DIR}/${d}"
    # -a preserves modes/timestamps; this overlays pack files over existing
    # ones without deleting operator-added files.
    cp -a "${src}/." "${MC_DIR}/${d}/"
  done
  printf '%s' "${PACK_VERSION}" > "${PACK_MARKER}"
  log "pack ${PACK_VERSION} seeded"
else
  log "pack ${PACK_VERSION} already installed on volume"
fi

# NOTE: deceasedcraft/ installed several deployment-owned KubeJS scripts and
# quest chapters here (spawn command, infection recovery, Create train speed,
# Open Parties and Claims wilderness fix). All of that was specific to that
# pack's mods and content, none of which Mythic Prehistory ships. The quest
# book for this pack is authored in seed/config/ftbquests/ and seeded above,
# so there is nothing to install at boot.

cp -f "${MC_HOME}/seed/default-server.properties" "${DC_STATE}/default-server.properties"

# --- 3. EULA -----------------------------------------------------------------
# Mojang's EULA must be accepted to run a server. This records acceptance made
# by the operator deploying this repository.
if [[ ! -f "${MC_DIR}/eula.txt" ]] || ! grep -q '^eula=true' "${MC_DIR}/eula.txt"; then
  printf '# Accepted via deployment. https://aka.ms/MinecraftEULA\neula=true\n' \
    > "${MC_DIR}/eula.txt"
  log "Minecraft EULA accepted"
fi

# --- 4. RCON credentials ------------------------------------------------------
# RCON is bound only inside the machine and is NOT published in fly.toml, so it
# is unreachable from the internet. It still gets a strong password because the
# Fly private network is a trust boundary worth respecting.
if [[ -n "${RCON_PASSWORD:-}" ]]; then
  printf '%s' "${RCON_PASSWORD}" > "${RCON_PASS_FILE}"
  log "using RCON password from secret"
elif [[ ! -s "${RCON_PASS_FILE}" ]]; then
  python3 -c 'import secrets,sys; sys.stdout.write(secrets.token_urlsafe(32))' \
    > "${RCON_PASS_FILE}"
  log "generated a new random RCON password"
fi
chmod 600 "${RCON_PASS_FILE}"

# --- 5. server.properties -----------------------------------------------------
# Managed keys only; pack-shipped keys re-enforced; everything else preserved.
python3 /opt/mp/render_properties.py \
  --current       "${MC_DIR}/server.properties" \
  --pack-defaults "${DC_STATE}/default-server.properties" \
  --out           "${MC_DIR}/server.properties" \
  --set "server-port=${MC_PORT}" \
  --set "server-ip=" \
  --set "view-distance=${VIEW_DISTANCE}" \
  --set "simulation-distance=${SIMULATION_DISTANCE}" \
  --set "max-players=${MAX_PLAYERS}" \
  --set "online-mode=true" \
  --set "white-list=${WHITELIST_ENABLED}" \
  --set "enforce-whitelist=${WHITELIST_ENABLED}" \
  --set "enable-rcon=true" \
  --set "rcon.port=${RCON_PORT}" \
  --set "rcon.password=$(cat "${RCON_PASS_FILE}")" \
  --set "enable-query=false" \
  --set "motd=Mythic Prehistory ${PACK_VERSION}" \
  || die "failed to render server.properties"
chmod 600 "${MC_DIR}/server.properties"   # contains the RCON password
log "server.properties rendered (view=${VIEW_DISTANCE} sim=${SIMULATION_DISTANCE} max=${MAX_PLAYERS}, whitelist on, online-mode on)"

# --- 6. Whitelist / ops -------------------------------------------------------
# Created empty if absent so the server starts with a closed door rather than
# generating a permissive default.
[[ -f "${MC_DIR}/whitelist.json" ]] || echo '[]' > "${MC_DIR}/whitelist.json"
[[ -f "${MC_DIR}/ops.json" ]]       || echo '[]' > "${MC_DIR}/ops.json"
wl_count="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "${MC_DIR}/whitelist.json" 2>/dev/null || echo '?')"
log "whitelist entries: ${wl_count}"

# --- 7. JVM arguments ---------------------------------------------------------
# Conservative G1GC. Deliberately NOT the pack's run.bat flag soup (which pins
# MaxGCPauseMillis=37, enables UseLargePages, and other aggressive options that
# are a poor fit for a container and are known to destabilise long sessions).
# The pack's own Linux run.sh ships no tuning flags at all; this is a small,
# defensible set on top of that baseline.
cat > "${MC_DIR}/user_jvm_args.txt" <<EOF
# Generated on boot. Edit MC_HEAP in fly.toml, not this file.
-Xms${MC_HEAP}
-Xmx${MC_HEAP}
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16M
-XX:+ParallelRefProcEnabled
-XX:+DisableExplicitGC
-XX:ReservedCodeCacheSize=512M
-XX:+PerfDisableSharedMem
-XX:+UnlockExperimentalVMOptions
-XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40
-XX:G1ReservePercent=20
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=4
-XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5
-XX:InitiatingHeapOccupancyPercent=15
-XX:SurvivorRatio=32
-XX:MaxTenuringThreshold=1
-Dfile.encoding=UTF-8
-Djava.awt.headless=true
EOF
if [[ "${HEAP_DUMP_ON_OOM:-false}" == "true" ]]; then
  # Off by default: an 11 GB heap dump would consume a fifth of the volume.
  printf -- '-XX:+HeapDumpOnOutOfMemoryError\n-XX:HeapDumpPath=%s\n' \
    "${MC_DIR}/crash-reports" >> "${MC_DIR}/user_jvm_args.txt"
  log "heap dump on OOM ENABLED (writes up to ${MC_HEAP} to ${MC_DIR}/crash-reports)"
fi
log "JVM heap: ${MC_HEAP} (machine has 16 GB; ~5 GB reserved for native + OS)"

# --- 8. Signal handling -------------------------------------------------------
# Fly sends SIGINT (kill_signal in fly.toml) when stopping the machine. We must
# complete save + backup before the 300 s kill_timeout expires.
on_signal() {
  log "received stop signal; delegating to graceful shutdown"
  /opt/mp/shutdown.sh "operator-or-platform-stop" || log "WARN: shutdown script returned non-zero"
}
trap on_signal INT TERM

# --- 9. Background services ---------------------------------------------------
python3 /opt/mp/status_server.py &
STATUS_PID=$!
log "status server started (pid ${STATUS_PID}, port ${STATUS_PORT})"

/opt/mp/idle_monitor.sh &
IDLE_PID=$!
log "idle monitor started (pid ${IDLE_PID}, threshold ${IDLE_SHUTDOWN_MINUTES}m)"

cleanup() {
  kill "${STATUS_PID}" "${IDLE_PID}" 2>/dev/null || true
}
trap cleanup EXIT

# --- 10. Hand off to the supervisor ------------------------------------------
/opt/mp/supervisor.sh &
SUPERVISOR_PID=$!
log "supervisor started (pid ${SUPERVISOR_PID})"

# `wait` on a specific pid so trapped signals are handled promptly rather than
# being deferred until the child exits.
set +e
wait "${SUPERVISOR_PID}"
rc=$?
set -e

reason="$(cut -f2 "${SHUTDOWN_REASON_FILE}" 2>/dev/null || echo 'unknown')"
log "supervisor exited rc=${rc}; shutdown reason: ${reason}"
log "machine will now stop"
exit 0

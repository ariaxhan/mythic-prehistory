#!/usr/bin/env bash
# Pre-generate terrain around spawn using vanilla /forceload. No mods added.
#
#   pregen.sh [radius_chunks] [center_x] [center_z]
#
# Works by force-loading chunks in batches, which makes the server generate any
# that do not exist yet, then releasing them. Vanilla caps /forceload add at 256
# chunks per call, so the area is walked in 16x16 chunk tiles.
#
# Idle shutdown is paused for the duration and always restored on exit, so a
# long pregen cannot be cut off halfway.

set -uo pipefail

DC_COMPONENT="pregen"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

RADIUS="${1:-32}"        # in chunks; 32 chunks = 512 blocks in each direction
CENTER_X="${2:-0}"
CENTER_Z="${3:-0}"
TILE=16                  # 16x16 = 256 chunks, the vanilla per-command maximum
SETTLE="${PREGEN_SETTLE_SECONDS:-20}"

mc_running || die "the server is not running. Start it first."
is_ready   || die "the server is not ready yet. Wait for READY, then retry."

# Refuse to run while anyone is on: pregen is heavy and would just cause lag.
if count="$(player_count)"; then
  [[ "${count}" -eq 0 ]] || die "${count} player(s) connected. Pregen would make their game stutter. Run it when the server is empty."
else
  die "could not read the player count over RCON; refusing to start a heavy job blind"
fi

PAUSE_FLAG="${DC_STATE}/pause-idle"
cleanup() {
  log "releasing force-loaded chunks and saving"
  rcon forceload remove all >/dev/null 2>&1 || true
  rcon save-all flush       >/dev/null 2>&1 || true
  rm -f "${PAUSE_FLAG}"
  log "idle shutdown re-enabled"
}
trap cleanup EXIT INT TERM

date -u '+%Y-%m-%dT%H:%M:%SZ' > "${PAUSE_FLAG}"
log "idle shutdown paused for the duration of this pregen"

# Chunk-coordinate bounds. /forceload takes BLOCK coords and resolves the chunk
# containing them, so each chunk step is 16 blocks.
c_min_x=$(( CENTER_X / 16 - RADIUS ))
c_max_x=$(( CENTER_X / 16 + RADIUS ))
c_min_z=$(( CENTER_Z / 16 - RADIUS ))
c_max_z=$(( CENTER_Z / 16 + RADIUS ))
span=$(( (c_max_x - c_min_x + 1) * (c_max_z - c_min_z + 1) ))

log "pre-generating ${span} chunks: radius ${RADIUS} chunks ($(( RADIUS * 16 )) blocks) around ${CENTER_X},${CENTER_Z}"
log "this is a heavy job and city generation is slow; expect several minutes"

total_tiles=0
done_tiles=0
for (( x = c_min_x; x <= c_max_x; x += TILE )); do
  for (( z = c_min_z; z <= c_max_z; z += TILE )); do
    total_tiles=$(( total_tiles + 1 ))
  done
done

start_ts="$(date +%s)"
for (( x = c_min_x; x <= c_max_x; x += TILE )); do
  for (( z = c_min_z; z <= c_max_z; z += TILE )); do
    x2=$(( x + TILE - 1 )); (( x2 > c_max_x )) && x2=${c_max_x}
    z2=$(( z + TILE - 1 )); (( z2 > c_max_z )) && z2=${c_max_z}

    # block coords of the chunk corners
    bx1=$(( x * 16 ));  bz1=$(( z * 16 ))
    bx2=$(( x2 * 16 )); bz2=$(( z2 * 16 ))

    if ! out="$(rcon forceload add "${bx1}" "${bz1}" "${bx2}" "${bz2}" 2>&1)"; then
      log "WARN: forceload failed for tile ${x},${z}: ${out}"
      continue
    fi

    # Give the server time to actually generate the tile before releasing it.
    sleep "${SETTLE}"
    rcon forceload remove all >/dev/null 2>&1 || true

    done_tiles=$(( done_tiles + 1 ))
    elapsed=$(( $(date +%s) - start_ts ))
    log "tile ${done_tiles}/${total_tiles} done (${elapsed}s elapsed)"

    # Flush periodically so a mid-run interruption still keeps the work.
    if (( done_tiles % 5 == 0 )); then
      rcon save-all flush >/dev/null 2>&1 || true
      log "checkpoint saved"
    fi
  done
done

log "pregen complete: ${span} chunks around ${CENTER_X},${CENTER_Z} in $(( $(date +%s) - start_ts ))s"

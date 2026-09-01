#!/usr/bin/env bash
# The single backup implementation. Every caller -- idle shutdown, hourly
# session backup, pre-update, manual -- goes through here so there is exactly
# one definition of "a backup" to reason about and restore from.
#
# Usage: backup.sh <label> [--no-remote] [--no-quiesce]
#
#   <label>       short reason tag, becomes part of the filename
#   --no-quiesce  skip the RCON save-off/save-all/save-on dance (only valid
#                 when the server is already stopped, i.e. nothing can write)
#   --no-remote   skip the R2 upload (local snapshot only)
#
# Safety contract: the archive is only ever written while the world is
# quiesced, either because the JVM is stopped or because save-off is in effect.

set -euo pipefail

DC_COMPONENT="backup"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

LABEL="${1:-manual}"
shift || true
QUIESCE=1
REMOTE=1
for arg in "$@"; do
  case "${arg}" in
    --no-remote)  REMOTE=0 ;;
    --no-quiesce) QUIESCE=0 ;;
    *) die "unknown argument: ${arg}" ;;
  esac
done

# Sanitise the label so it can never escape the filename.
LABEL="$(printf '%s' "${LABEL}" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-40)"

mkdir -p "${DC_BACKUPS}"
STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
ARCHIVE="${DC_BACKUPS}/dc-${STAMP}-${LABEL}.tar.zst"
MANIFEST="${ARCHIVE}.json"

# Local retention: how many archives to keep on the volume.
LOCAL_KEEP="${BACKUP_LOCAL_KEEP:-8}"

cd "${MC_DIR}"

# Resolve the world directory from server.properties rather than assuming
# "world" -- the pack or operator may have set a different level-name.
LEVEL_NAME="$(sed -n 's/^level-name=//p' server.properties 2>/dev/null | head -1)"
LEVEL_NAME="${LEVEL_NAME:-world}"

# Explicit allowlist. Everything that is mutable game state goes in; anything
# reproducible from the image (mods, libraries) or regenerable (logs, caches)
# stays out. mods/ and libraries/ are symlinks into the image and would be
# followed by tar, so excluding them is load-bearing, not cosmetic.
INCLUDE=()
for item in \
    "${LEVEL_NAME}" \
    config defaultconfigs kubejs scripts \
    local journeymap ftbbackups2 \
    whitelist.json ops.json banned-players.json banned-ips.json \
    usercache.json server.properties eula.txt .dc/pack-version
do
  [[ -e "${item}" ]] && INCLUDE+=("${item}")
done

[[ " ${INCLUDE[*]} " == *" ${LEVEL_NAME} "* ]] \
  || die "world directory '${LEVEL_NAME}' not found -- refusing to write a backup with no world in it"

# --- quiesce ------------------------------------------------------------------
# save-off stops the server writing chunks; save-all flush forces everything
# already dirty to disk and does not return until it is done. Together they
# guarantee the archive sees a consistent world.
# The condition is deliberately `mc_running` and NOT `is_ready`. What determines
# whether the world can be written mid-archive is simply "is the JVM alive" --
# a server that is shutting down has already had its ready flag cleared but is
# still very much able to write chunks. Gating on readiness here silently
# skipped the quiesce for every pre-shutdown backup.
quiesced=0
if [[ "${QUIESCE}" -eq 1 ]] && mc_running; then
  log "quiescing world (save-off + save-all flush)"
  if rcon save-off >/dev/null 2>&1; then
    quiesced=1
  else
    die "could not disable autosave over RCON -- refusing to snapshot a live, writable world"
  fi
  if ! rcon save-all flush >/dev/null 2>&1; then
    rcon save-on >/dev/null 2>&1 || true
    die "save-all flush failed -- refusing to snapshot a possibly half-written world"
  fi
  # Brief settle so in-flight region writes land before tar opens the files.
  sleep 3
  log "world quiesced"
elif [[ "${QUIESCE}" -eq 1 ]]; then
  log "JVM is not running; the world is already at rest, no quiesce needed"
fi

restore_saving() {
  if [[ "${quiesced}" -eq 1 ]]; then
    rcon save-on >/dev/null 2>&1 && log "autosave re-enabled" || log "WARN: failed to re-enable autosave"
    quiesced=0
  fi
}
trap restore_saving EXIT

# --- archive ------------------------------------------------------------------
log "creating ${ARCHIVE}"
log "including: ${INCLUDE[*]}"
if ! tar -I 'zstd -6 -T0' \
        --exclude='*/session.lock' \
        --exclude='./logs' \
        --exclude='./backups' \
        -cf "${ARCHIVE}.partial" "${INCLUDE[@]}"; then
  rm -f "${ARCHIVE}.partial"
  die "tar failed -- no backup written"
fi

# Only now does it get its real name. A reader can therefore trust that any
# file NOT ending in .partial is complete.
mv "${ARCHIVE}.partial" "${ARCHIVE}"
restore_saving
trap - EXIT

SIZE="$(stat -c %s "${ARCHIVE}")"
SHA="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
log "archive written: $(numfmt --to=iec "${SIZE}") sha256=${SHA:0:16}..."

# --- integrity verification ---------------------------------------------------
# Listing the archive forces zstd to decompress every frame and tar to parse
# every header, so a truncated or corrupt archive fails here rather than at
# restore time when it actually matters.
log "verifying archive integrity"
if ! tar -I zstd -tf "${ARCHIVE}" > /tmp/backup-listing.txt 2>/tmp/backup-verify.err; then
  log "ERROR: archive failed verification: $(head -3 /tmp/backup-verify.err)"
  mv "${ARCHIVE}" "${ARCHIVE}.CORRUPT"
  die "backup verification failed; archive quarantined as ${ARCHIVE}.CORRUPT"
fi
ENTRIES="$(wc -l < /tmp/backup-listing.txt)"
grep -q "^${LEVEL_NAME}/level.dat" /tmp/backup-listing.txt \
  || grep -q "^${LEVEL_NAME}/" /tmp/backup-listing.txt \
  || { mv "${ARCHIVE}" "${ARCHIVE}.CORRUPT"; die "archive contains no world data; quarantined"; }
log "verified: ${ENTRIES} entries, world data present"

cat > "${MANIFEST}" <<EOF
{
  "archive": "$(basename "${ARCHIVE}")",
  "created_utc": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "label": "${LABEL}",
  "bytes": ${SIZE},
  "sha256": "${SHA}",
  "entries": ${ENTRIES},
  "level_name": "${LEVEL_NAME}",
  "pack_version": "$(cat "${DC_STATE}/pack-version" 2>/dev/null || echo unknown)",
  "quiesced": $([[ "${QUIESCE}" -eq 1 ]] && echo true || echo false)
}
EOF

date -u '+%Y-%m-%dT%H:%M:%SZ' > "${LAST_BACKUP_FILE}"

# --- off-site copy ------------------------------------------------------------
if [[ "${REMOTE}" -eq 1 && -n "${R2_BUCKET:-}" ]]; then
  log "uploading to R2 bucket ${R2_BUCKET}"
  if python3 /opt/mp/r2.py upload "${ARCHIVE}" "${MANIFEST}"; then
    log "uploaded to R2"
    python3 /opt/mp/r2.py prune --keep "${R2_KEEP:-2}" \
      || log "WARN: R2 retention prune failed; the new off-site archive is intact"
  else
    # A failed off-site copy must not fail the backup -- the local archive is
    # already verified and is the thing that protects the world right now.
    log "WARN: R2 upload failed; local archive is intact at ${ARCHIVE}"
  fi
elif [[ "${REMOTE}" -eq 1 ]]; then
  log "R2 not configured (R2_BUCKET unset); local backup only"
fi

# --- local retention ----------------------------------------------------------
# Never prune below the keep count, and never prune the archive just written.
mapfile -t OLD < <(ls -1t "${DC_BACKUPS}"/dc-*.tar.zst 2>/dev/null | tail -n +$((LOCAL_KEEP + 1)))
for old in "${OLD[@]:-}"; do
  [[ -n "${old}" ]] || continue
  log "pruning old local backup: $(basename "${old}")"
  rm -f "${old}" "${old}.json"
done

log "backup complete: $(basename "${ARCHIVE}")"
printf '%s\n' "${ARCHIVE}"

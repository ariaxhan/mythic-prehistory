#!/usr/bin/env bash
# Restore a backup, or test-restore one without touching the live world.
#
#   restore.sh <archive|latest> --test      extract to a scratch dir and verify.
#                                           NEVER touches the live world.
#   restore.sh <archive|latest> --confirm   real restore. Requires the server to
#                                           be stopped, and takes a fresh backup
#                                           of the current world first.
#
# There is no default mode on purpose: an unqualified invocation does nothing.

set -euo pipefail

DC_COMPONENT="restore"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

TARGET="${1:-}"
MODE="${2:-}"

[[ -n "${TARGET}" ]] || die "usage: restore.sh <archive|latest> --test|--confirm"

case "${MODE}" in
  --test|--confirm) ;;
  *) die "refusing to act without an explicit mode: pass --test or --confirm" ;;
esac

if [[ "${TARGET}" == "latest" ]]; then
  ARCHIVE="$(ls -1t "${DC_BACKUPS}"/dc-*.tar.zst 2>/dev/null | head -1 || true)"
  [[ -n "${ARCHIVE}" ]] || die "no backups found in ${DC_BACKUPS}"
else
  ARCHIVE="${DC_BACKUPS}/$(basename "${TARGET}")"
fi

# A restore after a volume teardown starts from an EMPTY /data/backups: the only
# surviving copy is off-site. Rather than fail with "archive not found" at the
# exact moment someone is rebuilding from nothing, try to pull it from R2 first.
# Named archives only -- "latest" is meaningless without a local listing to sort.
if [[ ! -f "${ARCHIVE}" && "${TARGET}" != "latest" ]]; then
  log "not present locally: ${ARCHIVE}"
  if [[ -x /opt/mp/r2.py ]] || [[ -f /opt/mp/r2.py ]]; then
    log "attempting to fetch it from off-site storage"
    mkdir -p "${DC_BACKUPS}"
    if python3 /opt/mp/r2.py download \
         "mythic-prehistory/$(basename "${TARGET}")" "${ARCHIVE}"; then
      log "fetched from R2: ${ARCHIVE}"
      # The sidecar carries the recorded sha256; verify_backup.sh below uses it,
      # so a corrupted download is caught before anything touches the world.
      python3 /opt/mp/r2.py download \
        "mythic-prehistory/$(basename "${TARGET}").json" "${ARCHIVE}.json" \
        >/dev/null 2>&1 || log "no sidecar metadata off-site (continuing)"
    else
      die "archive not found locally and could not be fetched from R2: $(basename "${TARGET}")"
    fi
  else
    die "archive not found: ${ARCHIVE} (and r2.py is unavailable to fetch it)"
  fi
fi

[[ -f "${ARCHIVE}" ]] || die "archive not found: ${ARCHIVE}"

# Never restore something we have not just proven readable.
log "verifying ${ARCHIVE} before doing anything with it"
/opt/mp/verify_backup.sh "$(basename "${ARCHIVE}")" || die "verification failed; refusing to restore"

LEVEL_NAME="$(sed -n 's/^level-name=//p' "${MC_DIR}/server.properties" 2>/dev/null | head -1)"
LEVEL_NAME="${LEVEL_NAME:-world}"

# --- test mode ---------------------------------------------------------------
if [[ "${MODE}" == "--test" ]]; then
  SCRATCH="${MC_DIR}/restore-test/$(date -u '+%Y%m%dT%H%M%SZ')"
  log "TEST RESTORE -- the live world will not be modified"
  log "extracting to ${SCRATCH}"
  mkdir -p "${SCRATCH}"

  if ! tar -I zstd -xf "${ARCHIVE}" -C "${SCRATCH}"; then
    die "extraction failed"
  fi

  log "extracted; inspecting"
  [[ -f "${SCRATCH}/${LEVEL_NAME}/level.dat" ]] \
    || die "restored tree has no ${LEVEL_NAME}/level.dat"

  regions="$(find "${SCRATCH}/${LEVEL_NAME}" -name '*.mca' 2>/dev/null | wc -l)"
  players="$(find "${SCRATCH}/${LEVEL_NAME}/playerdata" -name '*.dat' 2>/dev/null | wc -l)"
  configs="$(find "${SCRATCH}/config" -type f 2>/dev/null | wc -l)"
  leveldat_size="$(stat -c %s "${SCRATCH}/${LEVEL_NAME}/level.dat")"

  # level.dat is gzipped NBT; if gzip can read it, the file is structurally sound.
  if gzip -t "${SCRATCH}/${LEVEL_NAME}/level.dat" 2>/dev/null; then
    log "  level.dat: ${leveldat_size} bytes, valid gzip/NBT container"
  else
    die "level.dat is present but not a readable NBT container"
  fi

  log "  region files : ${regions}"
  log "  playerdata   : ${players}"
  log "  config files : ${configs}"
  log "  whitelist    : $(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))))' "${SCRATCH}/whitelist.json" 2>/dev/null || echo 'n/a') entr(y/ies)"
  log "TEST RESTORE PASSED -- archive is restorable"
  log "scratch copy left at ${SCRATCH} (remove it when you are done inspecting)"
  exit 0
fi

# --- real restore ------------------------------------------------------------
log "REAL RESTORE requested from $(basename "${ARCHIVE}")"

if mc_running; then
  die "the Minecraft server is still running. Stop it first (./mpctl stop), then restore."
fi

# Safety net: the current world becomes a restore point before we replace it.
log "backing up the CURRENT world before replacing it"
if ! /opt/mp/backup.sh "pre-restore" --no-quiesce >/dev/null; then
  die "could not back up the current world; refusing to restore over it"
fi
log "current world safely backed up"

STAGE="${MC_DIR}/.dc/restore-stage"
rm -rf "${STAGE}"
mkdir -p "${STAGE}"
log "extracting archive to a staging area"
tar -I zstd -xf "${ARCHIVE}" -C "${STAGE}" || die "extraction failed; live world untouched"
[[ -f "${STAGE}/${LEVEL_NAME}/level.dat" ]] || die "archive has no world; live world untouched"

# Swap rather than overwrite: the old tree is moved aside, not deleted, so a
# failed restore is still recoverable by hand.
RETIRED="${MC_DIR}/.dc/replaced-$(date -u '+%Y%m%dT%H%M%SZ')"
mkdir -p "${RETIRED}"
for item in "${LEVEL_NAME}" config defaultconfigs kubejs scripts \
            whitelist.json ops.json banned-players.json banned-ips.json \
            usercache.json server.properties; do
  [[ -e "${MC_DIR}/${item}" ]] && mv "${MC_DIR}/${item}" "${RETIRED}/" || true
  [[ -e "${STAGE}/${item}" ]] && mv "${STAGE}/${item}" "${MC_DIR}/" || true
done

rm -rf "${STAGE}"
log "restore complete from $(basename "${ARCHIVE}")"
log "the replaced files were moved to ${RETIRED} (delete once you are satisfied)"
log "start the server with: ./mpctl start"

#!/usr/bin/env bash
# Verify a backup archive without touching the live world.
#
#   verify_backup.sh latest        verify the newest local archive
#   verify_backup.sh <name>        verify a specific archive in /data/backups
#
# Checks, in order:
#   1. the archive exists and is not a .partial or .CORRUPT file
#   2. sha256 matches the manifest recorded at creation time
#   3. every zstd frame decompresses and every tar header parses
#   4. the archive actually contains world data (level.dat + region files)
#
# Exits non-zero on any failure, so it is usable as a gate in scripts.

set -euo pipefail

DC_COMPONENT="verify"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

TARGET="${1:-latest}"

if [[ "${TARGET}" == "latest" ]]; then
  ARCHIVE="$(ls -1t "${DC_BACKUPS}"/dc-*.tar.zst 2>/dev/null | head -1 || true)"
  [[ -n "${ARCHIVE}" ]] || die "no backups found in ${DC_BACKUPS}"
else
  ARCHIVE="${DC_BACKUPS}/$(basename "${TARGET}")"
fi

[[ -f "${ARCHIVE}" ]] || die "archive not found: ${ARCHIVE}"
case "${ARCHIVE}" in
  *.partial) die "refusing to verify an incomplete archive: ${ARCHIVE}" ;;
  *.CORRUPT) die "this archive was already quarantined as corrupt: ${ARCHIVE}" ;;
esac

log "verifying $(basename "${ARCHIVE}")"
SIZE="$(stat -c %s "${ARCHIVE}")"
log "size: $(numfmt --to=iec "${SIZE}")"

# --- 2. checksum against the manifest ----------------------------------------
MANIFEST="${ARCHIVE}.json"
if [[ -f "${MANIFEST}" ]]; then
  EXPECTED="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sha256"])' "${MANIFEST}")"
  log "recomputing sha256 (this reads the whole archive)"
  ACTUAL="$(sha256sum "${ARCHIVE}" | awk '{print $1}')"
  if [[ "${EXPECTED}" != "${ACTUAL}" ]]; then
    log "ERROR: checksum mismatch"
    log "  manifest: ${EXPECTED}"
    log "  actual  : ${ACTUAL}"
    die "archive has changed since it was written -- treat it as unusable"
  fi
  log "checksum OK (${ACTUAL:0:16}...)"
else
  log "WARN: no manifest alongside this archive; skipping checksum comparison"
fi

# --- 3+4. structural verification --------------------------------------------
LISTING="$(mktemp)"
trap 'rm -f "${LISTING}"' EXIT

log "decompressing and parsing every entry"
if ! tar -I zstd -tf "${ARCHIVE}" > "${LISTING}" 2>/tmp/verify.err; then
  log "ERROR: $(head -3 /tmp/verify.err)"
  die "archive is corrupt or truncated"
fi

ENTRIES="$(wc -l < "${LISTING}")"
log "entries: ${ENTRIES}"

LEVEL_NAME="$(python3 -c '
import json,sys
try:
    print(json.load(open(sys.argv[1]))["level_name"])
except Exception:
    print("world")
' "${MANIFEST}" 2>/dev/null || echo world)"

fail=0
check_contains() {
  local pattern="$1" label="$2"
  if grep -qE "${pattern}" "${LISTING}"; then
    log "  present: ${label}"
  else
    log "  MISSING: ${label}"
    fail=1
  fi
}

log "checking expected contents (level=${LEVEL_NAME})"
check_contains "^${LEVEL_NAME}/level\.dat$"        "world/level.dat"
check_contains "^${LEVEL_NAME}/region/.*\.mca$"    "region files"
check_contains "^whitelist\.json$"                 "whitelist.json"
check_contains "^server\.properties$"              "server.properties"
check_contains "^config/"                          "mod configs"

# playerdata only exists once someone has actually joined, so its absence is
# reported but is not a failure on a brand-new world.
if grep -qE "^${LEVEL_NAME}/playerdata/.*\.dat$" "${LISTING}"; then
  n="$(grep -cE "^${LEVEL_NAME}/playerdata/.*\.dat$" "${LISTING}")"
  log "  present: playerdata (${n} file(s))"
else
  log "  note   : no playerdata yet (nobody has joined this world)"
fi

if [[ "${fail}" -ne 0 ]]; then
  die "archive is readable but is missing expected world content"
fi

log "VERIFIED: $(basename "${ARCHIVE}") is complete, intact, and contains world data"

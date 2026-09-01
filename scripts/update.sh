#!/usr/bin/env bash
# Controlled pack update. Never runs automatically.
#
#   scripts/update.sh --version 5.5.6 [--server-file-id N] [--dry-run]
#
# Sequence:
#   1. verify the server is stopped and take a fresh, integrity-checked backup
#   2. record the currently deployed image + pack version as the rollback point
#   3. resolve and download the new official server pack from CurseForge
#   4. validate the archive (size, hash, expected contents) before committing
#   5. rewrite pack.env and deploy
#   6. verify the server actually boots and reaches ready
#   7. roll back automatically if it does not
#
# The world is never touched. Only the pack layer changes; configs are archived
# by the entrypoint before re-seeding, so a rollback restores them too.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_off=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "${c_grn}" "$*" "${c_off}"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s%s%s\n' "${c_ylw}" "$*" "${c_off}"; }
die()  { printf '%sERROR: %s%s\n' "${c_red}" "$*" "${c_off}" >&2; exit 1; }

NEW_VERSION=""
SERVER_FILE_ID=""
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)        NEW_VERSION="${2:-}"; shift 2 ;;
    --server-file-id) SERVER_FILE_ID="${2:-}"; shift 2 ;;
    --dry-run)        DRY_RUN=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done
[[ -n "${NEW_VERSION}" ]] || die "usage: scripts/update.sh --version <X.Y.Z> [--server-file-id N]"

for tool in flyctl jq curl python3; do
  command -v "${tool}" >/dev/null 2>&1 || die "required tool not found: ${tool}"
done

# shellcheck source=../pack.env
source ./pack.env
APP="$(sed -n 's/^app *= *"\(.*\)"/\1/p' fly.toml | head -1)"
ROLLBACK_DIR="${REPO_DIR}/.rollback"
mkdir -p "${ROLLBACK_DIR}"

step "Preflight"
info "current: ${PACK_DISPLAY} (MC ${MINECRAFT_VERSION} / Forge ${FORGE_VERSION})"
info "target : ${NEW_VERSION}"
[[ "${NEW_VERSION}" != "${PACK_VERSION}" ]] || die "already on ${PACK_VERSION}"

state="$(flyctl machines list --app "${APP}" --json 2>/dev/null | jq -r '.[0].state // "absent"')"
[[ "${state}" != "absent" ]] || die "no machine found for ${APP}"
if [[ "${state}" == "started" ]]; then
  die "the server is running. Stop it first with ./mpctl stop, so the backup is taken against a world at rest."
fi
info "machine state: ${state}"

# --- 1. verified backup -------------------------------------------------------
step "Pre-update backup"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  info "(dry run) would start the machine, back up, verify, and stop again"
else
  info "starting the machine briefly to take a backup"
  mid="$(flyctl machines list --app "${APP}" --json | jq -r '.[0].id')"
  flyctl machines start "${mid}" --app "${APP}" >/dev/null
  # The server itself does not need to be ready; the world is at rest either way.
  sleep 20
  flyctl ssh console --app "${APP}" --machine "${mid}" \
    -C "/opt/mp/backup.sh pre-update-${NEW_VERSION} --no-quiesce" \
    || die "pre-update backup failed; refusing to update"
  flyctl ssh console --app "${APP}" --machine "${mid}" \
    -C "/opt/mp/verify_backup.sh latest" \
    || die "pre-update backup failed verification; refusing to update"
  info "backup taken and verified"
  flyctl machines stop "${mid}" --app "${APP}" >/dev/null
fi

# --- 2. record the rollback point ---------------------------------------------
step "Recording rollback point"
CURRENT_IMAGE="$(flyctl status --app "${APP}" --json 2>/dev/null \
  | jq -r '.ImageDetails | "\(.Registry)/\(.Repository):\(.Tag)"' 2>/dev/null || true)"
if [[ -z "${CURRENT_IMAGE}" || "${CURRENT_IMAGE}" == *null* ]]; then
  CURRENT_IMAGE="$(flyctl image show --app "${APP}" --json 2>/dev/null | jq -r '.[0].Ref // empty' || true)"
fi
[[ -n "${CURRENT_IMAGE}" ]] || die "could not determine the currently deployed image; refusing to update without a rollback point"

cp pack.env "${ROLLBACK_DIR}/pack.env.previous"
cat > "${ROLLBACK_DIR}/rollback.json" <<EOF
{
  "recorded_utc": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "previous_pack_version": "${PACK_VERSION}",
  "previous_minecraft": "${MINECRAFT_VERSION}",
  "previous_forge": "${FORGE_VERSION}",
  "previous_image": "${CURRENT_IMAGE}",
  "updating_to": "${NEW_VERSION}"
}
EOF
info "rollback point: ${CURRENT_IMAGE} (pack ${PACK_VERSION})"
info "recorded in .rollback/rollback.json"

# --- 3. resolve the new official server pack ----------------------------------
step "Resolving official server pack for ${NEW_VERSION}"
UA='Mozilla/5.0'
CF_API="https://www.curseforge.com/api/v1/mods/${CF_PROJECT_ID}"

if [[ -z "${SERVER_FILE_ID}" ]]; then
  info "searching CurseForge project ${CF_PROJECT_ID} for a Release-channel file matching ${NEW_VERSION}"
  files_json="$(curl -fsS --max-time 60 -A "${UA}" -H 'Accept: application/json' \
    "${CF_API}/files?pageIndex=0&pageSize=50&sort=dateCreated&sortDescending=true")" \
    || die "could not query CurseForge"

  parent_id="$(jq -r --arg v "${NEW_VERSION}" '
      [ .data[]
        | select(.releaseType == 1)
        | select(.fileName | test("DH[_-]?Edition"; "i") | not)
        | select(.displayName | contains($v)) ]
      | first | .id // empty' <<<"${files_json}")"
  [[ -n "${parent_id}" ]] || die "no Release-channel file matching '${NEW_VERSION}' found. Pass --server-file-id explicitly."
  info "matched client file id ${parent_id}"

  SERVER_FILE_ID="$(curl -fsS --max-time 60 -A "${UA}" -H 'Accept: application/json' \
    "${CF_API}/files/${parent_id}/additional-files" \
    | jq -r '[.data[] | select(.fileName | test("server"; "i"))] | first | .id // empty')"
  [[ -n "${SERVER_FILE_ID}" ]] || die "release ${NEW_VERSION} has no official server pack. Refusing to improvise one."
fi

meta="$(curl -fsS --max-time 60 -A "${UA}" -H 'Accept: application/json' \
  "${CF_API}/files/${SERVER_FILE_ID}")" || die "could not fetch metadata for file ${SERVER_FILE_ID}"
NEW_FILENAME="$(jq -r '.data.fileName' <<<"${meta}")"
NEW_BYTES="$(jq -r '.data.fileLength' <<<"${meta}")"
NEW_RELEASE_TYPE="$(jq -r '.data.releaseType' <<<"${meta}")"
NEW_GAMEVERS="$(jq -r '.data.gameVersions | join(", ")' <<<"${meta}")"

info "server pack : ${NEW_FILENAME}"
info "file id     : ${SERVER_FILE_ID}"
info "size        : ${NEW_BYTES} bytes"
info "channel     : $([[ "${NEW_RELEASE_TYPE}" == "1" ]] && echo Release || echo "NOT Release (type ${NEW_RELEASE_TYPE})")"
info "game        : ${NEW_GAMEVERS}"
[[ "${NEW_RELEASE_TYPE}" == "1" ]] || warn "this is not a Release-channel file"

# CDN path is derived from the file id: 5525543 -> 5525/543
id_hi="${SERVER_FILE_ID:0:4}"
id_lo="${SERVER_FILE_ID:4}"
NEW_URL="https://mediafilez.forgecdn.net/files/${id_hi}/${id_lo}/${NEW_FILENAME}"

# --- 4. download and validate before committing to anything -------------------
step "Downloading and validating"
WORK="${REPO_DIR}/.cache/update-${NEW_VERSION}"
mkdir -p "${WORK}"
ZIP="${WORK}/${NEW_FILENAME}"

if [[ ! -f "${ZIP}" ]]; then
  info "downloading ${NEW_URL}"
  curl -fL --retry 3 --max-time 1800 -A "${UA}" -o "${ZIP}.partial" "${NEW_URL}" \
    || die "download failed"
  mv "${ZIP}.partial" "${ZIP}"
fi

ACTUAL_BYTES="$(stat -f %z "${ZIP}" 2>/dev/null || stat -c %s "${ZIP}")"
[[ "${ACTUAL_BYTES}" == "${NEW_BYTES}" ]] \
  || die "size mismatch: expected ${NEW_BYTES}, got ${ACTUAL_BYTES}"
NEW_SHA="$(shasum -a 256 "${ZIP}" | awk '{print $1}')"
info "sha256: ${NEW_SHA}"

info "inspecting archive contents"
NEW_ROOT="$(unzip -Z1 "${ZIP}" | awk -F/ 'NF>1 {print $1; exit}')"
[[ -n "${NEW_ROOT}" ]] || die "could not determine the archive's root directory"
info "root: ${NEW_ROOT}"

listing="$(unzip -Z1 "${ZIP}")"
for expected in mods config; do
  grep -q "^${NEW_ROOT}/${expected}/" <<<"${listing}" \
    || die "archive is missing expected directory: ${expected}"
done
NEW_FORGE_INSTALLER="$(grep -oE "forge-[0-9.]+-[0-9.]+-installer\.jar" <<<"${listing}" | head -1 || true)"
[[ -n "${NEW_FORGE_INSTALLER}" ]] || die "archive contains no Forge installer"
NEW_MC="$(sed -E 's/^forge-([0-9.]+)-([0-9.]+)-installer\.jar$/\1/' <<<"${NEW_FORGE_INSTALLER}")"
NEW_FORGE="$(sed -E 's/^forge-([0-9.]+)-([0-9.]+)-installer\.jar$/\2/' <<<"${NEW_FORGE_INSTALLER}")"
NEW_MODS="$(grep -c "^${NEW_ROOT}/mods/.*\.jar$" <<<"${listing}" || true)"

info "minecraft: ${NEW_MC}   forge: ${NEW_FORGE}   mods: ${NEW_MODS}"
[[ "${NEW_MODS}" -gt 100 ]] || die "implausible mod count (${NEW_MODS}); refusing"

if [[ "${NEW_MC}" != "${MINECRAFT_VERSION}" ]]; then
  warn "MINECRAFT VERSION CHANGES: ${MINECRAFT_VERSION} -> ${NEW_MC}"
  warn "An existing world is generally NOT safe to carry across a Minecraft version."
  warn "Re-run with UPDATE_ALLOW_MC_CHANGE=1 if you have decided this is what you want."
  [[ "${UPDATE_ALLOW_MC_CHANGE:-0}" == "1" ]] || die "aborted: Minecraft version change not approved"
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  step "Dry run complete"
  info "would update pack.env to ${NEW_VERSION} and deploy"
  info "resolved URL: ${NEW_URL}"
  info "resolved sha256: ${NEW_SHA}"
  exit 0
fi

# --- 5. rewrite pack.env and deploy -------------------------------------------
step "Updating pack.env"
python3 - "$@" <<PY
import re, pathlib
p = pathlib.Path("pack.env")
text = p.read_text()
subs = {
    "PACK_VERSION":      "${NEW_VERSION}",
    "PACK_DISPLAY":      "${NEW_ROOT}",
    "CF_SERVER_FILE_ID": "${SERVER_FILE_ID}",
    "SERVER_PACK_URL":   "${NEW_URL}",
    "SERVER_PACK_SHA256":"${NEW_SHA}",
    "SERVER_PACK_BYTES": "${NEW_BYTES}",
    "SERVER_PACK_ROOT":  "${NEW_ROOT}",
    "MINECRAFT_VERSION": "${NEW_MC}",
    "FORGE_VERSION":     "${NEW_FORGE}",
}
for key, value in subs.items():
    text = re.sub(rf'^{key}=.*$', f'{key}="{value}"', text, flags=re.M)
p.write_text(text)
print("    pack.env rewritten")
PY

step "Deploying ${NEW_VERSION}"
if ./scripts/deploy.sh; then
  info "deploy reported success"
else
  warn "deploy FAILED; rolling back"
  ./scripts/rollback.sh --auto || die "rollback also failed -- manual intervention required"
  die "update aborted and rolled back to ${PACK_VERSION}"
fi

# --- 6. verify it actually boots ----------------------------------------------
step "Verifying the updated server reaches ready"
if ./mpctl start; then
  info "server reached ready on ${NEW_VERSION}"
else
  warn "the updated server did NOT reach ready; rolling back"
  ./scripts/rollback.sh --auto || die "rollback also failed -- manual intervention required"
  die "update rolled back: ${NEW_VERSION} failed to start"
fi

step "Update complete"
info "now running ${NEW_VERSION} (MC ${NEW_MC} / Forge ${NEW_FORGE})"
info "rollback point retained in .rollback/ until the next update"
info "commit the pack.env change to record the deployed version in git"

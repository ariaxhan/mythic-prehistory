#!/usr/bin/env bash
# Roll the deployed pack back to the previously recorded version.
#
#   scripts/rollback.sh            interactive: shows the target and asks
#   scripts/rollback.sh --auto     non-interactive, used by update.sh on failure
#   scripts/rollback.sh --list     show available rollback points and backups
#
# This rolls back the IMAGE (the pack layer). It does not touch the world.
# If a bad update also damaged world state, restore a backup afterwards:
#   ./mpctl backups        # find the pre-update archive
#   ./mpctl restore <name>
#
# The rollback point is written by update.sh before it changes anything, so a
# rollback is only possible for an update that went through the proper path.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_off=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "${c_grn}" "$*" "${c_off}"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s%s%s\n' "${c_ylw}" "$*" "${c_off}"; }
die()  { printf '%sERROR: %s%s\n' "${c_red}" "$*" "${c_off}" >&2; exit 1; }

AUTO=0
LIST=0
case "${1:-}" in
  --auto) AUTO=1 ;;
  --list) LIST=1 ;;
  "")     ;;
  *) die "unknown argument: $1" ;;
esac

APP="$(sed -n 's/^app *= *"\(.*\)"/\1/p' fly.toml | head -1)"
ROLLBACK_DIR="${REPO_DIR}/.rollback"
POINT="${ROLLBACK_DIR}/rollback.json"

if [[ "${LIST}" -eq 1 ]]; then
  step "Rollback points"
  if [[ -f "${POINT}" ]]; then
    jq . "${POINT}"
  else
    info "none recorded (no update has been run through scripts/update.sh)"
  fi
  step "Fly release history"
  flyctl releases --app "${APP}" 2>/dev/null | head -15 || info "unavailable"
  step "Backups"
  ./mpctl backups 2>/dev/null || info "start the machine to list backups"
  exit 0
fi

[[ -f "${POINT}" ]] || die "no rollback point recorded at ${POINT}. Nothing to roll back to. Use 'flyctl releases --app ${APP}' to inspect history manually."

PREV_IMAGE="$(jq -r '.previous_image' "${POINT}")"
PREV_VERSION="$(jq -r '.previous_pack_version' "${POINT}")"
PREV_MC="$(jq -r '.previous_minecraft' "${POINT}")"
FROM_VERSION="$(jq -r '.updating_to' "${POINT}")"
RECORDED="$(jq -r '.recorded_utc' "${POINT}")"

[[ -n "${PREV_IMAGE}" && "${PREV_IMAGE}" != "null" ]] || die "rollback point has no image reference"

step "Rollback target"
info "from : ${FROM_VERSION}"
info "to   : ${PREV_VERSION} (MC ${PREV_MC})"
info "image: ${PREV_IMAGE}"
info "point recorded: ${RECORDED}"

if [[ "${AUTO}" -eq 0 ]]; then
  warn "This redeploys the previous image. The world is NOT modified."
  read -r -p "Type the version to roll back to (${PREV_VERSION}) to confirm: " confirm
  [[ "${confirm}" == "${PREV_VERSION}" ]] || die "confirmation did not match; aborted"
fi

# Stop first so the rollback deploy does not interrupt a live session.
state="$(flyctl machines list --app "${APP}" --json 2>/dev/null | jq -r '.[0].state // "absent"')"
if [[ "${state}" == "started" ]]; then
  info "stopping the running machine first"
  mid="$(flyctl machines list --app "${APP}" --json | jq -r '.[0].id')"
  flyctl machines stop "${mid}" --app "${APP}" >/dev/null || warn "stop returned non-zero; continuing"
fi

step "Redeploying ${PREV_IMAGE}"
flyctl deploy --app "${APP}" --image "${PREV_IMAGE}" --wait-timeout 20m \
  || die "rollback deploy failed. The previous image may have been garbage collected. Inspect: flyctl releases --app ${APP}"

# Restore the pack.env that matches the image we just redeployed, so the repo
# and the running deployment agree about which version is live.
if [[ -f "${ROLLBACK_DIR}/pack.env.previous" ]]; then
  cp "${ROLLBACK_DIR}/pack.env.previous" pack.env
  info "pack.env restored to ${PREV_VERSION}"
fi

step "Verifying the rolled-back server starts"
if ./mpctl start; then
  step "Rollback complete"
  info "running ${PREV_VERSION} again"
  warn "commit the restored pack.env so git reflects what is deployed"
else
  die "the rolled-back image did not reach ready. Check ./mpctl logs. The world is untouched; consider restoring a backup."
fi

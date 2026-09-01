#!/usr/bin/env bash
# Provision and deploy the Mythic Prehistory server on Fly.io.
#
# Idempotent: safe to re-run. Each step checks whether it has already been done
# and skips it rather than failing or duplicating resources.
#
# Provisions, in order:
#   1. the Fly app                         (once)
#   2. STATUS_TOKEN + RCON_PASSWORD secrets (generated once, kept in keychain)
#   3. the persistent volume in sjc         (once)
#   4. a dedicated IPv4                     (once -- required for raw TCP)
#   5. the image build + deploy             (every run)
#
# Never prints a secret value. Secrets are generated locally with the system
# CSPRNG, pushed to Fly's encrypted secret store, and mirrored into the macOS
# keychain so mpctl can authenticate without a file on disk.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_DIR}"

# shellcheck source=../pack.env
source ./pack.env

APP="$(sed -n 's/^app *= *"\(.*\)"/\1/p' fly.toml | head -1)"
REGION="$(sed -n 's/^primary_region *= *"\(.*\)"/\1/p' fly.toml | head -1)"
VOLUME_NAME="$(sed -n 's/^ *source *= *"\(.*\)"/\1/p' fly.toml | head -1)"
VOLUME_SIZE_GB="${VOLUME_SIZE_GB:-20}"

KEYCHAIN_STATUS_TOKEN="mythic-prehistory-status-token"

c_grn=$'\033[32m'; c_ylw=$'\033[33m'; c_red=$'\033[31m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
step() { printf '\n%s==> %s%s\n' "${c_grn}" "$*" "${c_off}"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    %s%s%s\n' "${c_ylw}" "$*" "${c_off}"; }
die()  { printf '%sERROR: %s%s\n' "${c_red}" "$*" "${c_off}" >&2; exit 1; }

for tool in flyctl jq security; do
  command -v "${tool}" >/dev/null 2>&1 || die "required tool not found: ${tool}"
done

[[ -n "${APP}"    ]] || die "could not read app name from fly.toml"
[[ -n "${REGION}" ]] || die "could not read primary_region from fly.toml"
[[ -n "${VOLUME_NAME}" ]] || die "could not read volume source from fly.toml"

step "Preflight"
flyctl auth whoami >/dev/null 2>&1 || die "not logged in to Fly. Run: flyctl auth login"
info "authenticated as $(flyctl auth whoami 2>/dev/null)"
info "app=${APP} region=${REGION} volume=${VOLUME_NAME} (${VOLUME_SIZE_GB} GB)"
info "pack=${PACK_DISPLAY} mc=${MINECRAFT_VERSION} forge=${FORGE_VERSION} java=${JAVA_MAJOR}"

# --- 1. app -------------------------------------------------------------------
step "Fly app"
# `// empty` guards the first run, where the list can be null rather than [].
if flyctl apps list --json 2>/dev/null \
     | jq -e --arg a "${APP}" '(. // []) | .[] | select(.Name==$a)' >/dev/null 2>&1; then
  info "app ${APP} already exists"
else
  info "creating app ${APP}"
  flyctl apps create "${APP}" --org "${FLY_ORG:-personal}" \
    || die "could not create app ${APP} (name may be taken; set a different app= in fly.toml)"
fi

# --- 2. secrets ---------------------------------------------------------------
step "Secrets"
# flyctl reports the field as lowercase `name`; accept either spelling so a
# future flyctl rename cannot silently make this think no secrets exist and
# rotate them on every single deploy.
existing_secrets="$(flyctl secrets list --app "${APP}" --json 2>/dev/null \
  | jq -r '(. // []) | .[] | (.name // .Name // empty)' 2>/dev/null || true)"

secret_exists() { grep -qx "$1" <<<"${existing_secrets}"; }

gen_token() { python3 -c 'import secrets,sys; sys.stdout.write(secrets.token_urlsafe(32))'; }

pending=()

if secret_exists STATUS_TOKEN; then
  info "STATUS_TOKEN already set on the app"
  if ! security find-generic-password -s "${KEYCHAIN_STATUS_TOKEN}" -w >/dev/null 2>&1; then
    warn "STATUS_TOKEN exists on Fly but is not in your keychain, so mpctl cannot read /status."
    warn "Rotating it so both sides match."
    token="$(gen_token)"
    pending+=("STATUS_TOKEN=${token}")
    security add-generic-password -U -s "${KEYCHAIN_STATUS_TOKEN}" \
      -a "${APP}" -w "${token}" >/dev/null
    info "new STATUS_TOKEN stored in keychain"
    unset token
  fi
else
  info "generating STATUS_TOKEN"
  token="$(gen_token)"
  pending+=("STATUS_TOKEN=${token}")
  security add-generic-password -U -s "${KEYCHAIN_STATUS_TOKEN}" \
    -a "${APP}" -w "${token}" >/dev/null
  info "stored in macOS keychain as '${KEYCHAIN_STATUS_TOKEN}'"
  unset token
fi

if secret_exists RCON_PASSWORD; then
  info "RCON_PASSWORD already set"
else
  info "generating RCON_PASSWORD (localhost-only, never exposed)"
  pending+=("RCON_PASSWORD=$(gen_token)")
fi

if [[ ${#pending[@]} -gt 0 ]]; then
  # --stage avoids triggering a deploy before the volume exists.
  flyctl secrets set --app "${APP}" --stage "${pending[@]}" >/dev/null \
    || die "failed to set secrets"
  info "set $(printf '%s\n' "${pending[@]}" | cut -d= -f1 | tr '\n' ' ')"
fi
unset pending

# R2 credentials are the operator's to provide; deploy.sh never invents them.
for name in R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET; do
  secret_exists "${name}" || { r2_missing=1; }
done
if [[ -n "${r2_missing:-}" ]]; then
  warn "Off-site backups are NOT configured (missing R2 secrets)."
  warn "Local backups on the volume still work. To enable R2 later:"
  warn "  flyctl secrets set --app ${APP} R2_ACCOUNT_ID=... R2_ACCESS_KEY_ID=... \\"
  warn "      R2_SECRET_ACCESS_KEY=... R2_BUCKET=..."
else
  info "R2 off-site backups configured"
fi

# --- 3. volume ----------------------------------------------------------------
step "Persistent volume"
vol_json="$(flyctl volumes list --app "${APP}" --json 2>/dev/null || echo '[]')"
vol_count="$(jq --arg n "${VOLUME_NAME}" '[.[] | select(.name==$n and .state!="destroyed")] | length' <<<"${vol_json}")"

if [[ "${vol_count}" -ge 1 ]]; then
  size="$(jq -r --arg n "${VOLUME_NAME}" 'first(.[] | select(.name==$n and .state!="destroyed")) | .size_gb' <<<"${vol_json}")"
  region="$(jq -r --arg n "${VOLUME_NAME}" 'first(.[] | select(.name==$n and .state!="destroyed")) | .region' <<<"${vol_json}")"
  info "volume ${VOLUME_NAME} exists: ${size} GB in ${region}"
  [[ "${region}" == "${REGION}" ]] || warn "volume is in ${region} but primary_region is ${REGION}"
else
  info "creating ${VOLUME_SIZE_GB} GB volume ${VOLUME_NAME} in ${REGION}"
  # Single volume on purpose: one machine, one world. No replicas to diverge.
  flyctl volumes create "${VOLUME_NAME}" \
    --app "${APP}" --region "${REGION}" --size "${VOLUME_SIZE_GB}" --yes \
    || die "volume creation failed"
  info "volume created"
fi

# --- 4. dedicated IPv4 --------------------------------------------------------
step "Networking"
ips="$(flyctl ips list --app "${APP}" --json 2>/dev/null || echo '[]')"
if jq -e '.[] | select(.Type=="v4" and .Region=="global")' <<<"${ips}" >/dev/null 2>&1 \
   || jq -e '.[] | select(.Type=="v4")' <<<"${ips}" >/dev/null 2>&1; then
  info "IPv4 already allocated: $(jq -r 'first(.[] | select(.Type=="v4")) | .Address' <<<"${ips}")"
else
  # Minecraft's protocol is raw TCP, not HTTP, so Fly's shared IPv4 cannot route
  # it. A dedicated IPv4 is required and costs $2/month.
  info "allocating a dedicated IPv4 (required for raw TCP; \$2/month)"
  flyctl ips allocate-v4 --app "${APP}" --yes || die "IPv4 allocation failed"
fi
if ! jq -e '.[] | select(.Type=="v6")' <<<"${ips}" >/dev/null 2>&1; then
  info "allocating IPv6 (free)"
  flyctl ips allocate-v6 --app "${APP}" >/dev/null 2>&1 || true
fi

# --- 5. deploy ----------------------------------------------------------------
# --- 5a. stop gracefully before replacing the machine -------------------------
# Observed behaviour: `flyctl deploy` against a RUNNING machine replaces it
# without delivering our kill_signal, so the JVM dies without saving. That risks
# an unclean world write. Stopping first routes through the full
# save -> backup -> stop sequence.
running_state="$(flyctl machines list --app "${APP}" --json 2>/dev/null | jq -r '.[0].state // "absent"')"
if [[ "${running_state}" == "started" ]]; then
  step "Stopping the running server before deploying"
  mid="$(flyctl machines list --app "${APP}" --json | jq -r '.[0].id')"

  # Fail closed. A running server must be READY with a proven zero player count.
  # UNKNOWN and PLAYING are both hard deployment stops.
  mode="$(./mpctl doctor --json 2>/dev/null | jq -r '.mode // "UNKNOWN"' 2>/dev/null || printf 'UNKNOWN')"
  [[ "${mode}" == "MAINTENANCE" ]] \
    || die "refusing deploy: running server mode is ${mode}; requires MAINTENANCE (READY with zero players)"

  info "graceful stop (saves and backs up first)"
  flyctl machines stop "${mid}" --app "${APP}" >/dev/null || warn "stop returned non-zero; continuing"
  waited=0
  while [[ "$(flyctl machines list --app "${APP}" --json 2>/dev/null | jq -r '.[0].state')" == "started" \
           && "${waited}" -lt 300 ]]; do
    sleep 5; waited=$((waited + 5))
  done
  info "stopped after ${waited}s"
  DEPLOY_WAS_RUNNING=1
fi

step "Build and deploy"
info "building on Fly's remote x86 builder (the pack is amd64-only in practice,"
info "and this avoids emulating the Forge installer on an arm64 Mac)"

flyctl deploy \
  --app "${APP}" \
  --remote-only \
  --wait-timeout 30m \
  --build-arg "MINECRAFT_VERSION=${MINECRAFT_VERSION}" \
  --build-arg "FORGE_VERSION=${FORGE_VERSION}" \
  --build-arg "FORGE_INSTALLER_URL=${FORGE_INSTALLER_URL}" \
  --build-arg "SERVER_MOD_COUNT=${SERVER_MOD_COUNT}" \
  || die "deploy failed"

step "Deployed"
ipv4="$(flyctl ips list --app "${APP}" --json 2>/dev/null | jq -r 'first(.[] | select(.Type=="v4")) | .Address // "none"')"
info "app      : ${APP}"
info "IPv4     : ${ipv4}"
info "connect  : ${ipv4}:25565  (or your DNS name once pointed here)"
info "status   : https://${APP}.fly.dev/healthz"
printf '\n'
info "Next: ./mpctl start   then   ./mpctl status"

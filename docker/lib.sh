#!/usr/bin/env bash
# Shared helpers for the Mythic Prehistory server runtime.
# Sourced by every script in /opt/mp. Never executed directly.

set -euo pipefail

MC_DIR="${MC_DIR:-/data}"
MC_HOME="${MC_HOME:-/opt/mc}"
DC_BIN="${DC_BIN:-/opt/mp}"

# All operational state lives in one place on the volume so a machine restart
# can reconstruct exactly what happened during the previous run.
DC_STATE="${MC_DIR}/.dc"
DC_BACKUPS="${MC_DIR}/backups"

READY_FLAG="${DC_STATE}/ready"
SHUTDOWN_REASON_FILE="${DC_STATE}/shutdown-reason"
LAST_BACKUP_FILE="${DC_STATE}/last-backup"
CRASH_COUNT_FILE="${DC_STATE}/crash-count"
RCON_PASS_FILE="${DC_STATE}/rcon.pass"
MC_PID_FILE="${DC_STATE}/mc.pid"
STOPPING_FLAG="${DC_STATE}/stopping"

log() {
  # Timestamped, component-tagged, line-buffered. Fly's log collector reads
  # stdout, so everything here lands in `fly logs` without extra plumbing.
  printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "${DC_COMPONENT:-dc}" "$*"
}

die() {
  log "FATAL: $*"
  exit 1
}

# Validate that a variable is set and non-empty. Used at the top of every
# script so a misconfigured deploy fails loudly instead of half-working.
require_env() {
  local name
  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      die "required environment variable ${name} is unset or empty"
    fi
  done
}

# Record why the server stopped, so the next boot (and the status endpoint)
# can report it rather than leaving an unexplained gap.
set_shutdown_reason() {
  mkdir -p "${DC_STATE}"
  printf '%s\t%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" > "${SHUTDOWN_REASON_FILE}"
  log "shutdown reason recorded: $*"
}

# --- RCON ---------------------------------------------------------------------
# Thin wrapper over the stdlib-only client. Returns the command's text output on
# stdout; non-zero exit means RCON was unreachable, which callers MUST treat as
# "unknown", never as "zero players".
rcon() {
  local pass
  pass="$(cat "${RCON_PASS_FILE}" 2>/dev/null || true)"
  [[ -n "${pass}" ]] || return 1
  RCON_PASSWORD="${pass}" python3 "${DC_BIN}/rcon.py" \
    --host 127.0.0.1 --port "${RCON_PORT:-25575}" "$@"
}

# Number of connected players, via RCON `list`.
#   prints an integer and returns 0 on success
#   returns 1 without printing if the count could not be determined
# Callers must fail safe: an indeterminate count is NOT an empty server.
player_count() {
  local out
  out="$(rcon list 2>/dev/null)" || return 1
  # Vanilla/Forge reply: "There are 2 of a max of 4 players online: alice, bob"
  local n
  n="$(printf '%s' "${out}" | sed -n 's/.*There are \([0-9]\{1,\}\) of a max.*/\1/p' | head -1)"
  [[ -n "${n}" ]] || return 1
  printf '%s' "${n}"
}

# Names of connected players, comma-separated. Empty string when nobody is on.
player_names() {
  local out
  out="$(rcon list 2>/dev/null)" || return 1
  printf '%s' "${out}" | sed -n 's/.*players online:[[:space:]]*//p' | head -1
}

is_ready() {
  [[ -f "${READY_FLAG}" ]]
}

mc_pid() {
  local p
  p="$(cat "${MC_PID_FILE}" 2>/dev/null || true)"
  [[ -n "${p}" ]] && kill -0 "${p}" 2>/dev/null && printf '%s' "${p}"
}

mc_running() {
  [[ -n "$(mc_pid)" ]]
}

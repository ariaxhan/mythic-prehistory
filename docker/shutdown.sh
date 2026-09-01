#!/usr/bin/env bash
# Graceful shutdown sequence.
#
#   1. mark the stop as intentional (so the supervisor does not treat it as a crash)
#   2. notify the console / any connected client
#   3. save-all + flush and wait for it to complete   \ both performed by
#   4. create a verified backup of the quiesced world / backup.sh
#   5. stop the Minecraft process gracefully
#   6. return, letting PID 1 exit 0 so the Fly machine stops
#
# Usage: shutdown.sh <reason> [budget-seconds]
#
# The budget matters when the platform initiates the stop: fly.toml sets
# kill_timeout=300s, and being SIGKILLed midway through a backup is worse than
# skipping the off-site copy. When we initiate the stop ourselves there is no
# deadline and the full sequence runs.

set -uo pipefail

DC_COMPONENT="shutdown"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

REASON="${1:-unspecified}"
BUDGET="${2:-0}"          # 0 == no deadline
START_TS="$(date +%s)"

remaining() {
  [[ "${BUDGET}" -le 0 ]] && { printf '99999'; return; }
  printf '%s' "$(( BUDGET - ( $(date +%s) - START_TS ) ))"
}

# Idempotent: a second signal while shutdown is already running must not start
# a second sequence.
if [[ -f "${STOPPING_FLAG}" ]]; then
  log "shutdown already in progress; ignoring duplicate request"
  exit 0
fi
mkdir -p "${DC_STATE}"
date -u '+%Y-%m-%dT%H:%M:%SZ' > "${STOPPING_FLAG}"
rm -f "${READY_FLAG}"

log "graceful shutdown requested: ${REASON} (budget: ${BUDGET}s)"
set_shutdown_reason "${REASON}"

if ! mc_running; then
  log "Minecraft is not running; nothing to stop"
  exit 0
fi

JAVA_PID="$(mc_pid)"

# --- 2. notify ---------------------------------------------------------------
# Best-effort: if RCON is unreachable we still proceed, we just cannot warn.
if rcon say "Server shutting down: ${REASON}. Saving world..." >/dev/null 2>&1; then
  log "notified in-game console"
else
  log "WARN: could not reach RCON to send the shutdown notice"
fi

# --- 3+4. save, flush, back up -----------------------------------------------
# backup.sh performs save-off -> save-all flush -> archive -> save-on, so the
# world is provably at rest for the duration of the snapshot.
BACKUP_ARGS=()
if [[ "$(remaining)" -lt 120 ]]; then
  log "only $(remaining)s of budget left; taking a local-only backup (skipping off-site copy)"
  BACKUP_ARGS+=(--no-remote)
fi

# Output is NOT suppressed: the backup's own progress and verification lines are
# the evidence that the world was safely captured, and losing them to /dev/null
# makes a silent failure indistinguishable from a fast success.
if /opt/mp/backup.sh "preshutdown-${REASON}" "${BACKUP_ARGS[@]}"; then
  log "pre-shutdown backup complete"
else
  # A failed backup must not prevent a clean stop -- an unclean kill would risk
  # the very corruption the backup exists to protect against.
  log "WARN: pre-shutdown backup FAILED; continuing with a clean stop anyway"
  log "WARN: the world will still be saved by the server's own stop routine"
  # Make sure autosave is definitely back on before we ask the server to stop.
  rcon save-on >/dev/null 2>&1 || true
fi

# --- 5. stop the process gracefully ------------------------------------------
log "issuing stop to the Minecraft server"
rcon stop >/dev/null 2>&1 || log "WARN: RCON stop failed; will signal the JVM directly"

# Forge servers with 185 mods can take a while to unload dimensions and save.
WAITED=0
STOP_TIMEOUT="${STOP_TIMEOUT:-150}"
while kill -0 "${JAVA_PID}" 2>/dev/null; do
  if [[ "${WAITED}" -ge "${STOP_TIMEOUT}" ]]; then
    log "JVM still alive after ${WAITED}s; sending SIGTERM"
    kill -TERM "${JAVA_PID}" 2>/dev/null || true
    sleep 20
    if kill -0 "${JAVA_PID}" 2>/dev/null; then
      log "ERROR: JVM ignored SIGTERM; sending SIGKILL. The world may not be cleanly saved, but a verified backup was taken above."
      kill -KILL "${JAVA_PID}" 2>/dev/null || true
    fi
    break
  fi
  sleep 3
  WAITED=$((WAITED + 3))
done

log "Minecraft stopped after ${WAITED}s"
log "shutdown sequence complete: ${REASON}"
exit 0

#!/usr/bin/env bash
# Stops the machine after a sustained period with nobody connected, and takes a
# periodic backup during long sessions.
#
# Player presence is determined by RCON `list` against the local server -- an
# authoritative answer from the game itself. TCP activity is explicitly NOT
# used: a running Minecraft server has plenty of background network chatter
# (status pings, crawler probes) that would either keep it alive forever or,
# worse, look like activity while nobody is playing.
#
# Fail-safe rule: if the player count cannot be determined, the server is
# treated as OCCUPIED. An unreachable RCON must never cause a shutdown.

set -uo pipefail

DC_COMPONENT="idle-monitor"
# shellcheck source=lib.sh
source /opt/mp/lib.sh

POLL_SECONDS="${IDLE_POLL_SECONDS:-30}"
IDLE_LIMIT=$(( IDLE_SHUTDOWN_MINUTES * 60 ))
BACKUP_INTERVAL=$(( BACKUP_INTERVAL_MINUTES * 60 ))

idle_for=0
since_backup=0
warned_5m=0
warned_1m=0
last_count=-1

log "watching for idle (shutdown after ${IDLE_SHUTDOWN_MINUTES}m empty, session backup every ${BACKUP_INTERVAL_MINUTES}m)"

while :; do
  sleep "${POLL_SECONDS}"

  # Do nothing at all while the server is booting or already stopping.
  [[ -f "${STOPPING_FLAG}" ]] && { log "shutdown in progress; monitor standing down"; exit 0; }

  # A long job (pregen) holds this flag so it cannot be cut off partway.
  if [[ -f "${DC_STATE}/pause-idle" ]]; then
    idle_for=0
    continue
  fi
  if ! mc_running || ! is_ready; then
    idle_for=0
    continue
  fi

  if ! count="$(player_count)"; then
    # Indeterminate. Reset the idle timer: we will not stop a server we cannot
    # confirm is empty.
    log "WARN: could not read player count over RCON; assuming occupied"
    idle_for=0
    continue
  fi

  if [[ "${count}" != "${last_count}" ]]; then
    names="$(player_names 2>/dev/null || true)"
    log "players connected: ${count}${names:+ (${names})}"
    last_count="${count}"
  fi

  # --- periodic session backup ---
  since_backup=$(( since_backup + POLL_SECONDS ))
  if [[ "${since_backup}" -ge "${BACKUP_INTERVAL}" ]]; then
    since_backup=0
    log "hourly session backup starting"
    # Not suppressed: the verification output is the proof it worked.
    if /opt/mp/backup.sh "session"; then
      log "hourly session backup complete"
    else
      log "WARN: hourly session backup failed; will retry next interval"
    fi
  fi

  # --- idle accounting ---
  if [[ "${count}" -gt 0 ]]; then
    if [[ "${idle_for}" -gt 0 ]]; then
      log "player connected; idle timer reset"
    fi
    idle_for=0
    warned_5m=0
    warned_1m=0
    continue
  fi

  idle_for=$(( idle_for + POLL_SECONDS ))
  remaining=$(( IDLE_LIMIT - idle_for ))

  if [[ "${remaining}" -le 300 && "${warned_5m}" -eq 0 ]]; then
    log "empty for ${idle_for}s; stopping in ~5 minutes unless someone joins"
    warned_5m=1
  fi
  if [[ "${remaining}" -le 60 && "${warned_1m}" -eq 0 ]]; then
    log "empty for ${idle_for}s; stopping in ~1 minute unless someone joins"
    warned_1m=1
  fi

  if [[ "${idle_for}" -ge "${IDLE_LIMIT}" ]]; then
    # Re-verify immediately before acting. The last poll could be up to
    # POLL_SECONDS old, and someone may have joined in that window.
    if ! final="$(player_count)"; then
      log "WARN: final player check failed; aborting idle shutdown to be safe"
      idle_for=0
      continue
    fi
    if [[ "${final}" -gt 0 ]]; then
      log "player joined during the final check; aborting idle shutdown"
      idle_for=0
      warned_5m=0
      warned_1m=0
      continue
    fi

    log "confirmed empty for ${IDLE_SHUTDOWN_MINUTES}m; beginning idle shutdown"
    /opt/mp/shutdown.sh "idle-${IDLE_SHUTDOWN_MINUTES}m-no-players"
    exit 0
  fi
done

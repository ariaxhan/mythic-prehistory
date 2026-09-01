#!/usr/bin/env bash
# Owns the Java process. Restarts it a bounded number of times for transient
# failures, and refuses to restart at all once the ceiling is hit -- a crash
# loop burns money and destroys the evidence needed to diagnose the cause.
#
# Always exits 0. A non-zero exit would make Fly restart the machine, which is
# exactly the loop this script exists to prevent. The *reason* is recorded in
# ${SHUTDOWN_REASON_FILE} and surfaced by the status endpoint.

set -uo pipefail

DC_COMPONENT="supervisor"
# shellcheck source=lib.sh
source /opt/mp/lib.sh
# shellcheck source=/opt/mp/pack.env
source /opt/mp/pack.env

CONSOLE_LOG="${MC_DIR}/logs/console.log"
DIAGNOSIS_FILE="${DC_STATE}/last-failure"
FORGE_ARGS="libraries/net/minecraftforge/forge/${MINECRAFT_VERSION}-${FORGE_VERSION}/unix_args.txt"

cd "${MC_DIR}" || die "cannot cd to ${MC_DIR}"
[[ -f "${FORGE_ARGS}" ]] || die "Forge args file missing: ${MC_DIR}/${FORGE_ARGS} (is the libraries symlink intact?)"

# Streams the server's output to the container log (so `fly logs` works), to a
# persistent console log on the volume (so it survives the machine stopping),
# and watches for the readiness banner.
stream_output() {
  local line
  while IFS= read -r line; do
    printf '%s\n' "${line}"
    printf '%s\n' "${line}" >> "${CONSOLE_LOG}"
    case "${line}" in
      # Vanilla/Forge readiness banner, e.g.
      # [Server thread/INFO]: Done (312.441s)! For help, type "help"
      *'Done ('*'For help, type'*)
        date -u '+%Y-%m-%dT%H:%M:%SZ' > "${READY_FLAG}"
        printf '%s [supervisor] SERVER READY -- accepting connections\n' \
          "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        ;;
    esac
  done
}

# Best-effort classification of why the server died, so the operator gets a
# cause rather than "it crashed". Reads the tail of the console log plus the
# newest crash report.
classify_failure() {
  local rc="$1"
  local tail_log crash_report evidence cause
  tail_log="$(tail -400 "${CONSOLE_LOG}" 2>/dev/null || true)"
  crash_report="$(ls -1t "${MC_DIR}/crash-reports"/crash-*.txt 2>/dev/null | head -1 || true)"
  evidence="${tail_log}"
  if [[ -n "${crash_report}" ]]; then
    evidence="${evidence}"$'\n'"$(head -120 "${crash_report}" 2>/dev/null || true)"
  fi

  # Look for positive kernel evidence of an OOM kill rather than inferring it
  # from the exit code alone: 137 is simply "killed by SIGKILL", which the OOM
  # killer uses but so does any manual or platform kill.
  local oom_evidence=""
  # /dev/kmsg never returns EOF, so the read must be time-bounded or this
  # function hangs forever and the supervisor never restarts the server.
  oom_evidence="$( { timeout 2 grep -hiE 'Out of memory: Kill|oom-kill' /dev/kmsg 2>/dev/null || true; } | tail -3 )"

  cause="unclassified"
  if [[ -n "${oom_evidence}" ]]; then
    cause="oom-kill: the kernel OOM killer terminated the JVM (kernel log confirms it). The machine ran out of RAM OUTSIDE the Java heap. Do NOT simply raise MC_HEAP -- that makes this worse. Investigate native memory growth."
  elif [[ "${rc}" -eq 137 ]]; then
    cause="sigkill: the JVM was killed with SIGKILL (exit 137) with no kernel OOM record. Most often the platform stopping the machine, a manual kill, or an OOM whose kernel log was not readable from the container. Correlate with the machine's stop events before assuming memory."
  elif grep -qi 'java.lang.OutOfMemoryError' <<<"${evidence}"; then
    cause="jvm-oom: the Java heap was exhausted (OutOfMemoryError). Investigate what is retaining memory before raising the heap."
  elif grep -qi 'Watching Server. For help, type' <<<"${evidence}" && grep -qi 'watchdog' <<<"${evidence}"; then
    cause="watchdog: a single tick exceeded max-tick-time. Note the pack ships max-tick-time=600000 (10 min), so this indicates a genuine hang, not slow worldgen."
  elif grep -qiE 'ServerHangWatchdog|A single server tick took' <<<"${evidence}"; then
    cause="watchdog: server tick hang detected."
  elif grep -qiE 'Missing or unsupported mandatory mods|Mod ID .* requires|ModLoadingException|Failed to load mod' <<<"${evidence}"; then
    cause="mod-loading: a mod failed to load or a dependency is unsatisfied. Usually a pack/version mismatch -- verify the deployed pack version matches pack.env."
  elif grep -qiE 'UnsupportedClassVersionError|has been compiled by a more recent version' <<<"${evidence}"; then
    cause="java-version: a class was compiled for a newer Java than the runtime. This pack requires Java ${JAVA_MAJOR}."
  elif grep -qiE 'Exception while reading player data|Failed to load player data|error loading player' <<<"${evidence}"; then
    cause="player-data: corrupt or unreadable player data. The offending playerdata file can be moved aside to let the player rejoin fresh."
  elif grep -qiE 'Chunk file at .* is in the wrong location|Exception reading|ChunkHolder|Failed to save chunk|corrupt.*chunk' <<<"${evidence}"; then
    cause="chunk: a chunk failed to load or save, possibly corrupt region data."
  elif grep -qiE 'Exception ticking entity|Ticking entity|Ticking block entity' <<<"${evidence}"; then
    cause="entity: an entity or block entity threw while ticking. The crash report names the coordinates."
  elif [[ "${rc}" -eq 143 ]]; then
    cause="terminated: the JVM received SIGTERM."
  fi

  {
    printf 'time=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'exit_code=%s\n' "${rc}"
    printf 'crash_report=%s\n' "${crash_report:-none}"
    printf 'cause=%s\n' "${cause}"
  } > "${DIAGNOSIS_FILE}"

  log "failure classified: ${cause}"
  [[ -n "${crash_report}" ]] && log "crash report preserved at ${crash_report}"
  return 0
}

restarts=0
printf '0' > "${CRASH_COUNT_FILE}"

while :; do
  rm -f "${READY_FLAG}"
  log "starting Minecraft (attempt $((restarts + 1)) of $((MAX_CRASH_RESTARTS + 1)))"
  log "java -Xms/-Xmx ${MC_HEAP} | Forge ${MINECRAFT_VERSION}-${FORGE_VERSION}"
  printf '\n===== server start %s =====\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "${CONSOLE_LOG}"

  # Process substitution keeps java as a direct child, so $! is the JVM's pid
  # and signals can be delivered to it precisely.
  java "@user_jvm_args.txt" "@${FORGE_ARGS}" nogui \
      < /dev/null > >(stream_output) 2>&1 &
  java_pid=$!
  printf '%s' "${java_pid}" > "${MC_PID_FILE}"
  log "JVM pid ${java_pid}"

  wait "${java_pid}"
  rc=$?
  rm -f "${MC_PID_FILE}" "${READY_FLAG}"
  log "JVM exited rc=${rc}"

  # An intentional stop (idle shutdown, operator stop, platform signal) sets
  # this flag before asking the server to stop. Anything else is a crash.
  if [[ -f "${STOPPING_FLAG}" ]]; then
    log "exit was intentional; supervisor finishing"
    exit 0
  fi

  classify_failure "${rc}"
  restarts=$((restarts + 1))
  printf '%s' "${restarts}" > "${CRASH_COUNT_FILE}"

  if [[ "${restarts}" -gt "${MAX_CRASH_RESTARTS}" ]]; then
    cause="$(sed -n 's/^cause=//p' "${DIAGNOSIS_FILE}" 2>/dev/null || echo unclassified)"
    log "CRASH LOOP CEILING REACHED (${restarts} failures). Not restarting."
    log "cause: ${cause}"
    log "logs and crash reports are preserved on the volume under ${MC_DIR}/logs and ${MC_DIR}/crash-reports"
    set_shutdown_reason "crash-loop: gave up after ${restarts} failures -- ${cause}"
    exit 0
  fi

  log "restarting in 15s (${restarts}/${MAX_CRASH_RESTARTS} transient-failure budget used)"
  sleep 15
done

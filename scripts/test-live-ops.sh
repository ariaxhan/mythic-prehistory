#!/usr/bin/env bash
# Deterministic safety checks for the operator surface. Never contacts Fly.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

bash -n mpctl scripts/*.sh docker/*.sh
python3 scripts/analyze_logs.py --self-test

# Burnt Basic's distant plume loop mutates entities while iterating the world's
# linked entity map. It crashed the live 1.1.0 server; keep that path disabled.
jq -e '.distant_smoke == false' seed/config/burnt_basic.json >/dev/null
# spark's background sampler kept the JVM alive after that crash, wedging the
# supervisor in wait(). On-demand profiling remains available.
jq -e '.backgroundProfiler == false' seed/config/spark/config.json >/dev/null

analysis="$(printf '%s\n' 'Authorization: Bearer TEST_SENTINEL lost connection: Timed out' \
  | python3 scripts/analyze_logs.py)"
! grep -Eq 'TEST_SENTINEL|Authorization|Bearer' <<<"${analysis}"
jq -e '.counts.disconnect == 1 and .counts.stall == 0 and (has("recent") | not)' \
  <<<"${analysis}" >/dev/null

# An unavailable Fly API must become UNKNOWN, never OFFLINE/MAINTENANCE.
unknown="$(bash -c 'flyctl(){ return 1; }; export -f flyctl; ./mpctl doctor --json')"
jq -e '.mode == "UNKNOWN" and .status.machine_state == "unknown"' \
  <<<"${unknown}" >/dev/null

if bash -c 'flyctl(){ return 1; }; export -f flyctl; ./mpctl status' >/dev/null 2>&1; then
  echo "status incorrectly succeeded when Fly state was unknown" >&2
  exit 1
fi

# A proven connected player must block disruptive operations. The fakes expose
# a PLAYING status without contacting Fly or reading the real keychain.
playing_harness='flyctl(){
  if [[ "$*" == *"machines list"* ]]; then
    printf '\''[{"id":"test-machine","state":"started"}]\n'\''
  else
    echo "unexpected Fly mutation attempted: $*" >&2
    return 99
  fi
}; security(){ printf '\''test-token\n'\''; }; curl(){ cat >/dev/null; printf '\''{"minecraft":{"ready":true,"process_state":"ready"},"players":{"count":1,"max":4,"names":["tester"]},"backups":{}}\n'\''; }; export -f flyctl security curl'

for blocked in 'stop' 'pregen 32 0 0' 'console say unsafe'; do
  output="$(bash -c "${playing_harness}; ./mpctl ${blocked}" 2>&1 || true)"
  grep -Eq 'requires MAINTENANCE, current mode is PLAYING|refusing RCON mutation while players are connected' \
    <<<"${output}" || {
      echo "PLAYING guard did not block: ${blocked}" >&2
      echo "${output}" >&2
      exit 1
    }
done

safe_harness='flyctl(){
  if [[ "$*" == *"machines list"* ]]; then
    printf '\''[{"id":"test-machine","state":"started"}]\n'\''
  elif [[ "$*" == *"ssh console"* ]]; then
    return 0
  else
    return 99
  fi
}; security(){ printf '\''test-token\n'\''; }; curl(){ cat >/dev/null; printf '\''{"minecraft":{"ready":true,"process_state":"ready"},"players":{"count":1,"max":4,"names":["tester"]},"backups":{}}\n'\''; }; export -f flyctl security curl'
safe_output="$(bash -c "${safe_harness}; ./mpctl console --live-safe 'clear a stuck effect' effect clear tester minecraft:slowness" 2>&1)"
grep -q 'live-safe RCON: clear a stuck effect' <<<"${safe_output}"

# Nether pregen must pass the dimension through to the remote script.
maintenance_harness='flyctl(){
  if [[ "$*" == *"machines list"* ]]; then
    printf '\''[{"id":"test-machine","state":"started"}]\n'\''
  elif [[ "$*" == *"ssh console"* ]]; then
    printf '\''%s\n'\'' "$*"
  else
    return 99
  fi
}; security(){ printf '\''test-token\n'\''; }; curl(){ cat >/dev/null; printf '\''{"minecraft":{"ready":true,"process_state":"ready"},"players":{"count":0,"max":4,"names":[]},"backups":{}}\n'\''; }; export -f flyctl security curl'
pregen_output="$(bash -c "${maintenance_harness}; ./mpctl pregen 16 -90 1075 minecraft:the_nether")"
grep -q '/opt/mp/pregen.sh 16 -90 1075 minecraft:the_nether' <<<"${pregen_output}"

echo "live-ops safety tests: pass"

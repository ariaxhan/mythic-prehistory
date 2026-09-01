#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${repo_dir}/pack.env"
site_dir="${1:-${repo_dir}/.cache/client-pack-site}"
installer="${repo_dir}/.cache/packwiz-installer-bootstrap.jar"
packwiz_bin="${PACKWIZ_BIN:-${repo_dir}/.cache/bin/packwiz}"
test -f "${site_dir}/pack.toml"
test -f "${installer}"
test -x "${packwiz_bin}"

test_site="$(mktemp -d)"
cp -R "${site_dir}/." "${test_site}/"
printf 'remove-me\n' > "${test_site}/config/updater-removal-probe.txt"
(cd "${test_site}" && "${packwiz_bin}" refresh --pack-file pack.toml >/dev/null)

port="${PACK_TEST_PORT:-18765}"
python3 -m http.server "${port}" --directory "${test_site}" >"${repo_dir}/.cache/client-pack-http.log" 2>&1 &
server_pid=$!
trap 'kill "${server_pid}" 2>/dev/null || true' EXIT

for _ in {1..20}; do
    curl -fsS "http://127.0.0.1:${port}/pack.toml" >/dev/null && break
    sleep 0.25
done

target="$(mktemp -d)"
personal="${target}/options.txt"
printf 'personal-marker\n' > "${personal}"
(cd "${target}" && java -jar "${installer}" -g "http://127.0.0.1:${port}/pack.toml")
first_hash="$(shasum -a 256 "${target}/packwiz.json" | awk '{print $1}')"
(cd "${target}" && java -jar "${installer}" -g "http://127.0.0.1:${port}/pack.toml")
second_hash="$(shasum -a 256 "${target}/packwiz.json" | awk '{print $1}')"

[[ "${first_hash}" == "${second_hash}" ]]
grep -qx 'personal-marker' "${personal}"
[[ "$(find "${target}/mods" -maxdepth 1 -name '*.jar' | wc -l | tr -d ' ')" -eq "${CLIENT_MOD_COUNT}" ]]
test -f "${target}/mods/packetfixer-3.3.2-1.18-1.20.4-merged.jar"
test -f "${target}/config/updater-removal-probe.txt"

rm "${test_site}/config/updater-removal-probe.txt"
(cd "${test_site}" && "${packwiz_bin}" refresh --pack-file pack.toml >/dev/null)
(cd "${target}" && java -jar "${installer}" -g "http://127.0.0.1:${port}/pack.toml" >/dev/null)
test ! -e "${target}/config/updater-removal-probe.txt"
grep -qx 'personal-marker' "${personal}"

corrupt_file="$(find "${test_site}/config" -type f -print -quit)"
printf 'corrupt\n' >> "${corrupt_file}"
corrupt_target="$(mktemp -d)"
if (cd "${corrupt_target}" && java -jar "${installer}" -g "http://127.0.0.1:${port}/pack.toml" >/dev/null 2>&1); then
    echo 'FATAL: corrupt indexed file was accepted' >&2
    exit 1
fi

printf 'PASS: install, idempotence, deletion, corruption rejection, personal files, %s mods\n' \
    "${CLIENT_MOD_COUNT}"

#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
instance_dir="${PRISM_INSTANCE_DIR:-${HOME}/Library/Application Support/PrismLauncher/instances/Mythic Prehistory}"
pack_url="${1:-}"
output_zip="${2:-${repo_dir}/.cache/MythicPrehistory-client.zip}"
bootstrap_url="https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar"
bootstrap_sha256="a8fbb24dc604278e97f4688e82d3d91a318b98efc08d5dbfcbcbcab6443d116c"

[[ "${pack_url}" == https://*/pack.toml ]] || {
    echo 'usage: scripts/export-client-bootstrap.sh https://host/path/pack.toml [output.zip]' >&2
    exit 1
}
[[ "${output_zip}" == /* ]] || output_zip="$(pwd)/${output_zip}"
test -f "${instance_dir}/mmc-pack.json"

work="$(mktemp -d)"
root="${work}/Mythic Prehistory"
mkdir -p "${root}/minecraft"
cp "${instance_dir}/mmc-pack.json" "${root}/mmc-pack.json"
[[ ! -f "${instance_dir}/minecraft/options.txt" ]] || cp "${instance_dir}/minecraft/options.txt" "${root}/minecraft/options.txt"
[[ ! -f "${instance_dir}/minecraft/servers.dat" ]] || cp "${instance_dir}/minecraft/servers.dat" "${root}/minecraft/servers.dat"

bootstrap="${repo_dir}/.cache/packwiz-installer-bootstrap.jar"
if [[ ! -f "${bootstrap}" ]]; then
    curl -fL --retry 3 -o "${bootstrap}" "${bootstrap_url}"
fi
printf '%s  %s\n' "${bootstrap_sha256}" "${bootstrap}" | shasum -a 256 -c -
cp "${bootstrap}" "${root}/minecraft/packwiz-installer-bootstrap.jar"

cat > "${root}/instance.cfg" <<EOF
[General]
ConfigVersion=1.3
InstanceType=OneSix
name=Mythic Prehistory
OverrideCommands=true
PreLaunchCommand="\$INST_JAVA" -jar packwiz-installer-bootstrap.jar ${pack_url}
OverrideJavaLocation=false
OverrideMemory=true
MinMemAlloc=2048
MaxMemAlloc=6144
EOF

mkdir -p "$(dirname "${output_zip}")"
(cd "${work}" && find 'Mythic Prehistory' -type f | LC_ALL=C sort | zip -X -q "${output_zip}" -@)
unzip -tq "${output_zip}" >/dev/null
printf 'bootstrap: %s\n' "${output_zip}"

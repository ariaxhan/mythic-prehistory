#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
instance_dir="${PRISM_INSTANCE_DIR:-${HOME}/Library/Application Support/PrismLauncher/instances/Mythic Prehistory}"
output_dir="${1:-${repo_dir}/.cache/client-pack-site}"
packwiz_bin="${PACKWIZ_BIN:-${repo_dir}/.cache/bin/packwiz}"
packetfixer_url="https://cdn.modrinth.com/data/c7m1mi73/versions/9F4NGhGR/packetfixer-3.3.2-1.18-1.20.4-merged.jar"
packetfixer_sha512="916501acefab2a33f7b5438375dec0c3d523975d82c807c98496227c107c1efd57c95d9e1501d657513324a9ad617eb8ef7e963921263389af896da55dc707a9"

# shellcheck disable=SC1091
source "${repo_dir}/pack.env"
mods_dir="${instance_dir}/minecraft/mods"
config_dir="${instance_dir}/minecraft/config"
test -x "${packwiz_bin}" || { echo "FATAL: packwiz missing: ${packwiz_bin}" >&2; exit 1; }
test -d "${mods_dir}" || { echo "FATAL: Prism mods missing: ${mods_dir}" >&2; exit 1; }
test -d "${config_dir}" || { echo "FATAL: Prism config missing: ${config_dir}" >&2; exit 1; }

build_dir="$(mktemp -d)"
mkdir -p "${build_dir}/mods"
cp -R "${config_dir}" "${build_dir}/config"
# Repo seed is the durable owner for pack-authored config and quests. Overlay it
# after Prism state so a release cannot silently publish stale local copies.
cp -R "${repo_dir}/seed/config/." "${build_dir}/config/"
cp "${repo_dir}/client-pack/metadata/"*.pw.toml "${build_dir}/mods/"

# Generated/personal client state is never pack-managed.
find "${build_dir}/config" -type f -name '*.bak' -delete
find "${build_dir}/config/jei/world" -type f -delete 2>/dev/null || true
find "${build_dir}/config" -type f \
    \( -name 'patrons_cache.json' -o -name 'xaeropatreon.txt' -o -name 'xaerohud.txt' \) \
    -delete

packetfixer="${repo_dir}/.cache/packetfixer-3.3.2-1.18-1.20.4-merged.jar"
if [[ ! -f "${packetfixer}" ]]; then
    curl -fL --retry 3 -o "${packetfixer}" "${packetfixer_url}"
fi
printf '%s  %s\n' "${packetfixer_sha512}" "${packetfixer}" | shasum -a 512 -c -

hashes="${build_dir}/hashes.tsv"
find "${mods_dir}" -maxdepth 1 -type f -name '*.jar' -print0 \
    | while IFS= read -r -d '' jar; do
        printf '%s\t%s\t%s\n' "$(shasum "${jar}" | awk '{print $1}')" "$(basename "${jar}")" "${jar}"
    done > "${hashes}"
printf '%s\t%s\t%s\n' \
    "$(shasum "${packetfixer}" | awk '{print $1}')" \
    "$(basename "${packetfixer}")" "${packetfixer}" >> "${hashes}"
sort -u -o "${hashes}" "${hashes}"

jq -Rn '[inputs | split("\t") | .[0]] | {hashes:., algorithm:"sha1"}' \
    < "${hashes}" > "${build_dir}/request.json"
curl -fsS -X POST -H 'Content-Type: application/json' \
    --data-binary "@${build_dir}/request.json" \
    https://api.modrinth.com/v2/version_files > "${build_dir}/modrinth.json"

is_client_only() {
    local filename="$1" prefix
    while IFS= read -r prefix; do
        [[ -n "${prefix}" && "${filename}" == "${prefix}"* ]] && return 0
    done < "${repo_dir}/CLIENT_ONLY.txt"
    return 1
}

known_unmatched='^(ftb-essentials-forge-2001\.2\.4\.jar|ftb-library-forge-2001\.2\.13\.jar|ftb-quests-forge-2001\.4\.22\.jar|ftb-teams-forge-2001\.3\.2\.jar|pelagic_prehistory-20\.1\.3\.2\.jar|mythic-companions-1\.2\.1\.jar|macu_lib-forge-1\.0\.6-1\.20\.1-mythic1\.jar)$'
while IFS=$'\t' read -r sha1 filename jar; do
    if rg -l -F "filename = \"${filename}\"" "${build_dir}/mods/"*.pw.toml >/dev/null 2>&1; then
        continue
    fi
    version="$(jq -c --arg hash "${sha1}" '.[$hash] // empty' "${build_dir}/modrinth.json")"
    if [[ -z "${version}" ]]; then
        if [[ ! "${filename}" =~ ${known_unmatched} ]]; then
            echo "FATAL: no approved download metadata for ${filename}" >&2
            exit 1
        fi
        case "${filename}" in
            mythic-companions-*.jar|macu_lib-*-mythic1.jar) cp "${jar}" "${build_dir}/mods/${filename}" ;;
        esac
        continue
    fi

    file="$(jq -c --arg hash "${sha1}" '[.files[] | select(.hashes.sha1 == $hash)] | first' <<<"${version}")"
    project_id="$(jq -r '.project_id' <<<"${version}")"
    version_id="$(jq -r '.id' <<<"${version}")"
    url="$(jq -r '.url' <<<"${file}")"
    sha512="$(jq -r '.hashes.sha512' <<<"${file}")"
    side="both"
    is_client_only "${filename}" && side="client"
    slug="$(printf '%s' "${filename%.jar}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g;s/^-|-$//g')"
    cat > "${build_dir}/mods/${slug}.pw.toml" <<EOF
name = "${filename%.jar}"
filename = "${filename}"
side = "${side}"

[download]
url = "${url}"
hash-format = "sha512"
hash = "${sha512}"

[update]
[update.modrinth]
mod-id = "${project_id}"
version = "${version_id}"
EOF
done < "${hashes}"

cat > "${build_dir}/pack.toml" <<EOF
name = "${PACK_NAME}"
author = "Aria"
version = "${PACK_VERSION}"
pack-format = "packwiz:1.1.0"

[index]
file = "index.toml"
hash-format = "sha256"
hash = ""

[versions]
forge = "${FORGE_VERSION}"
minecraft = "${MINECRAFT_VERSION}"
EOF

rm "${build_dir}/hashes.tsv" "${build_dir}/request.json" "${build_dir}/modrinth.json"
printf 'hash-format = "sha256"\nfiles = []\n' > "${build_dir}/index.toml"
(cd "${build_dir}" && "${packwiz_bin}" refresh --pack-file pack.toml)

generated_mods="$(find "${build_dir}/mods" -maxdepth 1 \( -name '*.pw.toml' -o -name '*.jar' \) | wc -l | tr -d ' ')"
[[ "${generated_mods}" -eq "${CLIENT_MOD_COUNT}" ]] || {
    echo "FATAL: expected ${CLIENT_MOD_COUNT} client mods, generated ${generated_mods}" >&2
    exit 1
}

mkdir -p "$(dirname "${output_dir}")"
if [[ -e "${output_dir}" ]]; then
    backup="${output_dir}.previous"
    suffix=1
    while [[ -e "${backup}" ]]; do
        backup="${output_dir}.previous.${suffix}"
        suffix=$((suffix + 1))
    done
    mv "${output_dir}" "${backup}"
fi
mv "${build_dir}" "${output_dir}"
printf 'client pack: %s mods; %s indexed files; %s\n' \
    "${generated_mods}" "$(rg -c '^file = ' "${output_dir}/index.toml")" "${output_dir}"

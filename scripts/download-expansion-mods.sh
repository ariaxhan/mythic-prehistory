#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_file="${EXPANSION_MODS_LOCK:-${repo_dir}/expansion-mods.lock.tsv}"
destination="${1:-${repo_dir}/.cache/expansion-mods}"

mkdir -p "${destination}"
verify_sha512() {
    local expected="$1" target="$2"
    if command -v sha512sum >/dev/null 2>&1; then
        printf '%s  %s\n' "${expected}" "${target}" | sha512sum -c -
    else
        printf '%s  %s\n' "${expected}" "${target}" | shasum -a 512 -c -
    fi
}

while IFS=$'\t' read -r filename sha512 url; do
    [[ -n "${filename}" && "${filename}" != \#* ]] || continue
    target="${destination}/${filename}"
    if [[ ! -f "${target}" ]] || ! verify_sha512 "${sha512}" "${target}" >/dev/null 2>&1; then
        curl -fL --retry 3 -o "${target}" "${url}"
    fi
    verify_sha512 "${sha512}" "${target}"
done < "${lock_file}"

missing=0
while IFS=$'\t' read -r filename _sha512 _url; do
    [[ -n "${filename}" && "${filename}" != \#* ]] || continue
    [[ -f "${destination}/${filename}" ]] || {
        echo "FATAL: expansion jar missing after download: ${filename}" >&2
        missing=1
    }
done < "${lock_file}"
[[ "${missing}" -eq 0 ]]

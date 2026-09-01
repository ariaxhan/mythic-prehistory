#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${repo_dir}/pack.env"

[[ "${PACK_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "FATAL: PACK_VERSION is not stable SemVer: ${PACK_VERSION}" >&2
    exit 1
}
[[ "${PACK_DISPLAY}" == "MythicPrehistory_v${PACK_VERSION}" ]] || {
    echo "FATAL: PACK_DISPLAY does not match PACK_VERSION" >&2
    exit 1
}
grep -Eq "^## \[${PACK_VERSION//./\\.}\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" "${repo_dir}/CHANGELOG.md" || {
    echo "FATAL: CHANGELOG.md has no dated ${PACK_VERSION} release" >&2
    exit 1
}
grep -Fq "Mythic Prehistory ${PACK_VERSION}" "${repo_dir}/README.md" || {
    echo "FATAL: README.md does not name ${PACK_VERSION}" >&2
    exit 1
}

if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    [[ "${GITHUB_REF_NAME:-}" == "v${PACK_VERSION}" ]] || {
        echo "FATAL: tag ${GITHUB_REF_NAME:-unset} does not match v${PACK_VERSION}" >&2
        exit 1
    }
fi

printf 'version=%s display=%s client_mods=%s server_mods=%s\n' \
    "${PACK_VERSION}" "${PACK_DISPLAY}" "${CLIENT_MOD_COUNT}" "${SERVER_MOD_COUNT}"

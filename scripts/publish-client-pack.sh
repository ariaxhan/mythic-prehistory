#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
site_dir="${1:-${repo_dir}/.cache/client-pack-site}"
bucket="${R2_PACK_BUCKET:-mythic-prehistory-pack}"
public_base="${PACK_PUBLIC_BASE:-https://mythic-pack.ariaxhan.com}"
bootstrap_zip="${repo_dir}/.cache/MythicPrehistory-client.zip"

test -f "${site_dir}/pack.toml"
test -f "${site_dir}/index.toml"
command -v wrangler >/dev/null

content_type() {
    case "$1" in
        *.toml) printf 'text/plain; charset=utf-8' ;;
        *.json) printf 'application/json' ;;
        *.jar) printf 'application/java-archive' ;;
        *.zip) printf 'application/zip' ;;
        *) printf 'application/octet-stream' ;;
    esac
}

upload() {
    local file="$1" key="${1#"${site_dir}"/}"
    wrangler r2 object put "${bucket}/${key}" \
        --remote --file "${file}" --content-type "$(content_type "${file}")" \
        --cache-control 'public, no-cache' --force >/dev/null
}

# The manifest arms the release. Everything it can reference must exist first.
while IFS= read -r -d '' file; do
    upload "${file}"
done < <(find "${site_dir}" -type f ! -name pack.toml -print0 | sort -z)

while IFS= read -r path; do
    curl -fsS --retry 10 --retry-all-errors --retry-delay 3 \
        "${public_base}/${path}" -o /dev/null
done < <(awk -F '"' '/^file = / { print $2 }' "${site_dir}/index.toml")

upload "${site_dir}/pack.toml"
curl -fsS --retry 10 --retry-all-errors --retry-delay 3 \
    "${public_base}/pack.toml" -o /dev/null
"${repo_dir}/scripts/export-client-bootstrap.sh" \
    "${public_base}/pack.toml" "${bootstrap_zip}"
wrangler r2 object put "${bucket}/downloads/MythicPrehistory-client.zip" \
    --remote --file "${bootstrap_zip}" --content-type application/zip \
    --cache-control 'public, no-cache' --force >/dev/null
curl -fsS --retry 10 --retry-all-errors --retry-delay 3 \
    "${public_base}/downloads/MythicPrehistory-client.zip" -o /dev/null
printf 'published %s files to %s\n' "$(find "${site_dir}" -type f | wc -l | tr -d ' ')" "${public_base}"

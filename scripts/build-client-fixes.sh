#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_jar="$(find "${repo_dir}/mods" -maxdepth 1 -name 'shineals_prehistoric_expansion-*.jar' -print -quit)"
target="${1:-${repo_dir}/seed/config/paxi/resourcepacks/mythic-client-fixes.zip}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

test -f "${source_jar}" || { echo "FATAL: Shineal's jar missing" >&2; exit 1; }
mkdir -p "${work_dir}/assets/shineals_prehistoric_expansion/models/custom"
cp "${repo_dir}/client-fixes/pack.mcmeta" "${work_dir}/pack.mcmeta"

for model in utahraptorskeleton dodoskeleton; do
  path="assets/shineals_prehistoric_expansion/models/custom/${model}.json"
  unzip -qq "${source_jar}" "${path}" -d "${work_dir}"
done

perl -pi -e 's/"angle": (?:27\.5|30)/"angle": 22.5/g' \
  "${work_dir}/assets/shineals_prehistoric_expansion/models/custom/utahraptorskeleton.json"
perl -pi -e 's/"angle": 10/"angle": 0/g' \
  "${work_dir}/assets/shineals_prehistoric_expansion/models/custom/dodoskeleton.json"

find "${work_dir}" -type f -exec touch -t 202001010000 {} +
mkdir -p "$(dirname "${target}")"
rm -f "${target}"
(cd "${work_dir}" && find . -type f | LC_ALL=C sort | zip -X -q "${target}" -@)

for model in utahraptorskeleton dodoskeleton; do
  invalid="$(unzip -p "${target}" "assets/shineals_prehistoric_expansion/models/custom/${model}.json" \
    | jq '[.. | objects | select(has("angle")) | .angle | select(. != -45 and . != -22.5 and . != 0 and . != 22.5 and . != 45)] | length')"
  test "${invalid}" -eq 0 || { echo "FATAL: ${model} still has invalid rotations" >&2; exit 1; }
done

sha256sum "${target}"

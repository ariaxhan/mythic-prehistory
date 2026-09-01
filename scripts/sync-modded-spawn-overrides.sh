#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---check}"
case "${MODE}" in
  --check|--write) ;;
  *) echo "usage: $0 [--check|--write]" >&2; exit 2 ;;
esac

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODS_DIR="${REPO_DIR}/mods"
PACK_DIR="${REPO_DIR}/../custom-mod/pack/datapacks/mythic-spawns"
ZIP_TARGET="${REPO_DIR}/seed/config/paxi/datapacks/mythic-spawns.zip"
FACTOR=3
EXPECTED_WEIGHTS=98
NAMESPACES=(aquaculture fishofthieves pelagic_prehistory shineals_prehistoric_expansion species tameablebeasts)

for tool in cmp find jq mktemp python3 rg unzip zip; do
  command -v "${tool}" >/dev/null 2>&1 || { echo "missing tool: ${tool}" >&2; exit 1; }
done
[[ -d "${PACK_DIR}" ]] || { echo "missing datapack source: ${PACK_DIR}" >&2; exit 1; }

SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT
GENERATED="${SCRATCH}/generated"
mkdir -p "${GENERATED}"
weight_count=0

while IFS= read -r -d '' jar; do
  while IFS= read -r entry; do
    json="$(unzip -p "${jar}" "${entry}")"
    entries="$(jq '[
      (.spawners? | if . == null then empty elif type == "array" then .[] else . end | select(.weight != null)),
      (.spawn? | select(. != null and .weight != null))
    ] | length' <<<"${json}")"
    (( entries > 0 )) || continue

    destination="${GENERATED}/${entry}"
    mkdir -p "$(dirname "${destination}")"
    jq --argjson factor "${FACTOR}" '
      if .spawners != null then
        .spawners |= (
          if type == "array" then
            map(if .weight != null then .weight *= $factor else . end)
          elif .weight != null then .weight *= $factor
          else . end
        )
      else . end
      | if .spawn != null and .spawn.weight != null then
          .spawn.weight *= $factor
        else . end
    ' <<<"${json}" > "${destination}"
    weight_count=$((weight_count + entries))
  done < <(unzip -Z1 "${jar}" | grep -E '^data/[^/]+/forge/biome_modifier/.+\.json$')
done < <(find "${MODS_DIR}" -maxdepth 1 -type f -name '*.jar' -print0)

[[ "${weight_count}" -eq "${EXPECTED_WEIGHTS}" ]] || {
  echo "expected ${EXPECTED_WEIGHTS} weighted spawn entries, found ${weight_count}" >&2
  exit 1
}

if [[ "${MODE}" == "--write" ]]; then
  while IFS= read -r -d '' generated; do
    relative="${generated#${GENERATED}/}"
    destination="${PACK_DIR}/${relative}"
    mkdir -p "$(dirname "${destination}")"
    cp -f "${generated}" "${destination}"
  done < <(find "${GENERATED}" -type f -name '*.json' -print0)
fi

for namespace in "${NAMESPACES[@]}"; do
  actual_dir="${PACK_DIR}/data/${namespace}/forge/biome_modifier"
  expected_dir="${GENERATED}/data/${namespace}/forge/biome_modifier"
  diff -u \
    <(find "${expected_dir}" -type f -name '*.json' -print | sed "s#^${GENERATED}/##" | sort) \
    <(if [[ -d "${actual_dir}" ]]; then find "${actual_dir}" -type f -name '*.json' -print | sed "s#^${PACK_DIR}/##" | sort; fi)
done

while IFS= read -r -d '' generated; do
  relative="${generated#${GENERATED}/}"
  cmp -s "${generated}" "${PACK_DIR}/${relative}" || {
    echo "spawn override drift: ${relative}" >&2
    exit 1
  }
done < <(find "${GENERATED}" -type f -name '*.json' -print0)

ZIP_BUILD="${SCRATCH}/mythic-spawns.zip"
(
  cd "${PACK_DIR}"
  find . -type f ! -name '.DS_Store' -print | LC_ALL=C sort | zip -X -q "${ZIP_BUILD}" -@
)

if [[ "${MODE}" == "--write" ]]; then
  cp -f "${ZIP_BUILD}" "${ZIP_TARGET}"
else
  cmp -s "${ZIP_BUILD}" "${ZIP_TARGET}" || {
    echo "datapack zip is stale: ${ZIP_TARGET}" >&2
    exit 1
  }
fi

python3 "${REPO_DIR}/scripts/audit-loot.py"

echo "spawn overrides: ${weight_count} weights x${FACTOR}; datapack zip synchronized"

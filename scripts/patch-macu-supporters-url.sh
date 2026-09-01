#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_jar="${1:-${repo_dir}/mods/macu_lib-forge-1.0.6-1.20.1.jar.disabled}"
target_jar="${2:-${repo_dir}/mods/macu_lib-forge-1.0.6-1.20.1-mythic1.jar}"
work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

old_url='https://raw.githubusercontent.com/macuguita/macuguita-website/refs/heads/main/supporters.json'
new_url='https://raw.githubusercontent.com/macuguita/macuguita-website/main/static/supporters.json?x=x'
test "${#old_url}" -eq "${#new_url}" || { echo "FATAL: replacement changes class-file width" >&2; exit 1; }
test -f "${source_jar}" || { echo "FATAL: Macu Lib source jar missing: ${source_jar}" >&2; exit 1; }

(cd "${work_dir}" && unzip -qq "${source_jar}")
class_file="${work_dir}/com/macuguita/lib/supporters/RoleChecker.class"
OLD_URL="${old_url}" NEW_URL="${new_url}" perl -pi -e 's/\Q$ENV{OLD_URL}\E/$ENV{NEW_URL}/g' "${class_file}"
grep -aFq "${new_url}" "${class_file}" || { echo "FATAL: patched URL missing" >&2; exit 1; }
if grep -aFq "${old_url}" "${class_file}"; then
  echo "FATAL: stale URL survived patch" >&2
  exit 1
fi

find "${work_dir}" -type f -exec touch -t 202001010000 {} +
rm -f "${target_jar}"
(cd "${work_dir}" && find . -type f | LC_ALL=C sort | zip -X -q "${target_jar}" -@)
unzip -tq "${target_jar}" >/dev/null
sha256sum "${target_jar}"

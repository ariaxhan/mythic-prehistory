#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
instance_dir="${PRISM_INSTANCE_DIR:-${HOME}/Library/Application Support/PrismLauncher/instances/Mythic Prehistory}"
mods_dir="$instance_dir/minecraft/mods"
jar_name="mythic-companions-1.2.1.jar"
source_jar="$repo_dir/companion-mod/build/libs/$jar_name"
target_jar="$mods_dir/$jar_name"
config_dir="$instance_dir/minecraft/config"

if pgrep -lf java | grep -Fq 'Mythic Prehistory'; then
    echo 'FATAL: Mythic Prehistory is running; exit the client before replacing mods.' >&2
    exit 1
fi

test -d "$mods_dir" || { echo "FATAL: Prism mods directory missing: $mods_dir" >&2; exit 1; }
"$repo_dir/companion-mod/gradlew" -p "$repo_dir/companion-mod" clean test build
test -f "$source_jar"

for old_jar in "$mods_dir"/mythic-companions-*.jar; do
    [[ -e "$old_jar" ]] || continue
    [[ "$old_jar" == "$target_jar" ]] || mv "$old_jar" "$old_jar.disabled"
done

cp "$source_jar" "$target_jar"
mkdir -p "$config_dir/ftbquests/quests" "$config_dir/paxi/resourcepacks"
cp "$repo_dir/seed/config/modular_backpacks-client.toml" "$config_dir/modular_backpacks-client.toml"
cp "$repo_dir/seed/config/burnt_basic.json" "$config_dir/burnt_basic.json"
mkdir -p "$config_dir/spark"
cp "$repo_dir/seed/config/spark/config.json" "$config_dir/spark/config.json"
mkdir -p "$config_dir/xaero/minimap" "$config_dir/xaero/world-map"
cp "$repo_dir/seed/config/xaero/minimap/client.cfg" "$config_dir/xaero/minimap/client.cfg"
cp "$repo_dir/seed/config/xaero/world-map/client.cfg" "$config_dir/xaero/world-map/client.cfg"
cp -R "$repo_dir/seed/config/ftbquests/quests/." "$config_dir/ftbquests/quests/"
cp "$repo_dir/seed/config/paxi/resourcepacks/mythic-client-fixes.zip" \
    "$config_dir/paxi/resourcepacks/mythic-client-fixes.zip"
shasum -a 256 "$target_jar"

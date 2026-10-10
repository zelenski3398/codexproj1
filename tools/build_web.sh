#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
godot_bin="${GODOT_BIN:-godot}"
output_dir="$project_dir/builds/web"
mkdir -p "$output_dir"
"$godot_bin" --headless --path "$project_dir" --editor --import --quit
"$godot_bin" --headless --path "$project_dir" --export-release Web "$output_dir/index.html"
cp "$project_dir/web/GODOT-LICENSE.txt" "$project_dir/web/GODOT-COPYRIGHT.txt" "$output_dir/"
cp "$project_dir/assets/fonts/DejaVu-LICENSE.txt" "$output_dir/DejaVu-LICENSE.txt"
cp "$project_dir/assets/malta/ATTRIBUTION.txt" "$output_dir/MALTA-ATTRIBUTION.txt"
touch "$output_dir/.nojekyll"
printf 'Browser build: %s\n' "$output_dir"

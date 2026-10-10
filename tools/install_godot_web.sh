#!/usr/bin/env bash
# Linux setup using official releases and their published SHA-512 checksums.
set -euo pipefail
version=4.6.3
tools_dir="${GODOT_WEB_TOOLS:-/tmp/first-sortie-godot}"
cache="${GODOT_DOWNLOAD_CACHE:-/tmp/first-sortie-downloads}"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
templates_dir="$data_root/godot/export_templates/$version.stable"
base_url="https://github.com/godotengine/godot/releases/download/$version-stable"
mkdir -p "$cache" "$tools_dir" "$templates_dir"
curl --fail --location --retry 3 "$base_url/SHA512-SUMS.txt" -o "$cache/SHA512-SUMS.txt"
fetch_verified() {
    artifact="$1"
    if ! test -f "$cache/$artifact"; then
        curl --fail --location --retry 3 "$base_url/$artifact" -o "$cache/$artifact.part"
        mv "$cache/$artifact.part" "$cache/$artifact"
    fi
    # Verify even cached downloads; checksum failure exits rather than bypassing it.
    (cd "$cache"; awk -v name="$artifact" '$2 == name {print; found=1} END {if (!found) exit 1}' SHA512-SUMS.txt | sha512sum --check --strict)
}
if command -v godot >/dev/null && [[ "$(godot --version)" == "$version.stable."* ]]; then
    installed=$(command -v godot)
    if [[ "$installed" != "$tools_dir/godot" ]]; then
        ln -sf "$installed" "$tools_dir/godot"
    fi
else
    binary="Godot_v$version-stable_linux.x86_64.zip"
    fetch_verified "$binary"
    unzip -o "$cache/$binary" -d "$tools_dir"
    mv "$tools_dir/Godot_v$version-stable_linux.x86_64" "$tools_dir/godot"
    chmod +x "$tools_dir/godot"
fi
# These inner-archive hashes were derived from the official SHA-512-verified TPZ.
# They allow repeated setup in a retained snapshot without re-fetching 1.2 GB.
if test -f "$templates_dir/web_nothreads_release.zip" && test -f "$templates_dir/web_nothreads_debug.zip" &&
    (cd "$templates_dir"; printf '%s\n' \
    'be2efc7d6c158d04d09e949cd7756dfcef40e9bf0ada5f73fbdc7cc375b6a48c71da423c855c0cf14f5f515e4f78ed5d658870a64cc6b89eab350c8d9b119330  web_nothreads_release.zip' \
    'b80e34b560ecc036b718e84ea620ddcc33d2b7c9bc741178e9146538f6f1497b6ebbfa9f7bd75d5e912e72cb1b054c3ceca2e0f5769216e083c219904a4aa40f  web_nothreads_debug.zip' | sha512sum --check --strict); then
    printf 'Verified web templates already installed.\n'
else
    templates="Godot_v$version-stable_export_templates.tpz"
    fetch_verified "$templates"
    unzip -j -o "$cache/$templates" templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt -d "$templates_dir"
fi
"$tools_dir/godot" --version
printf 'Godot executable: %s/godot\n' "$tools_dir"

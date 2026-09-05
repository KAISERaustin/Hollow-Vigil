#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")" && pwd)"
godot_bin="${GODOT_PATH:-}"
if [[ -z "$godot_bin" ]]; then
    for candidate in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
        if [[ -x "$candidate" ]]; then
            godot_bin="$candidate"
            break
        fi
    done
fi
if [[ -z "$godot_bin" || ! -x "$godot_bin" ]]; then
    echo 'Install Godot 4.7.2, or set GODOT_PATH to its executable.' >&2
    exit 1
fi

"$godot_bin" --headless --path "$project_dir" --editor --import
exec "$godot_bin" --path "$project_dir" "$@"

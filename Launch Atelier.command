#!/bin/bash
set -euo pipefail

atelier_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
atelier_app="$atelier_project_dir/dist/Atelier.app"
atelier_executable="$atelier_app/Contents/MacOS/ArchitectureEngine"
atelier_rebuild=false

# An explicit build prepares the cache and returns without opening the app.
if [[ "${1:-}" == build ]]; then
    shift
    exec "$atelier_project_dir/scripts/build-app.sh" "$@"
fi

if [[ ! -x "$atelier_executable" || ! -f "$atelier_app/Contents/Info.plist" || ! -f "$atelier_app/Contents/Resources/ArchitectureEngine_ArchitectureEngine.bundle/Resources/Renderer.metal" || ! -f "$atelier_app/Contents/Resources/Atelier.icns" ]]; then
    atelier_rebuild=true
elif [[ -n "$(/usr/bin/find "$atelier_project_dir/Sources" "$atelier_project_dir/Package.swift" "$atelier_project_dir/scripts/build-app.sh" "$atelier_project_dir/scripts/create-icon.swift" "$atelier_project_dir/assets/Atelier.icns" -type f -newer "$atelier_executable" -print -quit)" ]]; then
    atelier_rebuild=true
fi

if [[ "$atelier_rebuild" == true ]]; then
    "$atelier_project_dir/scripts/build-app.sh"
fi

cd -- "$atelier_project_dir"
if [[ "$#" -gt 0 ]]; then
    exec "$atelier_executable" "$@"
fi
/usr/bin/open "$atelier_app"

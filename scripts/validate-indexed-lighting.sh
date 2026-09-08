#!/bin/zsh
set -euo pipefail
repo_root=${0:A:h:h}
build_folder=$(mktemp -d /tmp/atelier-lighting-validation.XXXXXX)
swiftc -O "$repo_root/Sources/ArchitectureEngine/SceneTypes.swift" "$repo_root/Sources/ArchitectureEngine/LightGrid.swift" "$repo_root/Tests/Lighting/main.swift" -o "$build_folder/validate-lighting"
"$build_folder/validate-lighting" "$@"

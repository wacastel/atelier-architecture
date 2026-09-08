#!/bin/zsh
set -euo pipefail
repo_root=${0:A:h:h}
build_folder=$(mktemp -d /tmp/atelier-traffic-validation.XXXXXX)
swiftc -O "$repo_root/Sources/ArchitectureEngine/SceneTypes.swift" "$repo_root/Sources/ArchitectureEngine/CollisionWorld.swift" "$repo_root/Sources/ArchitectureEngine/LightGrid.swift" "$repo_root/Sources/ArchitectureEngine/Traffic.swift" "$repo_root/Sources/ArchitectureEngine/TrafficMetal.swift" "$repo_root/Sources/ArchitectureEngine/MetalRenderer.swift" "$repo_root/Tests/Traffic/main.swift" -o "$build_folder/validate-traffic"
"$build_folder/validate-traffic" "$@"

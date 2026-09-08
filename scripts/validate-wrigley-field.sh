#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
wrigley_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-wrigley-validation.XXXXXX")
trap 'rm -rf "$wrigley_validation_dir"' EXIT
swiftc -O Sources/ArchitectureEngine/SceneTypes.swift Sources/ArchitectureEngine/EiffelScene.swift Sources/ArchitectureEngine/ParisEnvironment.swift Sources/ArchitectureEngine/RiverEnvironment.swift Sources/ArchitectureEngine/NightLighting.swift Sources/ArchitectureEngine/CollisionWorld.swift Sources/ArchitectureEngine/WrigleyField.swift Tests/WrigleyFieldGeometry/main.swift -o "$wrigley_validation_dir/validate"
"$wrigley_validation_dir/validate"

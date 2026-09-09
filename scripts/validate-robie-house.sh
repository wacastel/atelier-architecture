#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
robie_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-robie-validation.XXXXXX")
trap 'rm -rf "$robie_validation_dir"' EXIT
swiftc -O Sources/ArchitectureEngine/SceneTypes.swift Sources/ArchitectureEngine/EiffelScene.swift Sources/ArchitectureEngine/ParisEnvironment.swift Sources/ArchitectureEngine/RiverEnvironment.swift Sources/ArchitectureEngine/NightLighting.swift Sources/ArchitectureEngine/CollisionWorld.swift Sources/ArchitectureEngine/RobieHouse.swift Tests/RobieHouseGeometry/main.swift -o "$robie_validation_dir/validate"
"$robie_validation_dir/validate"

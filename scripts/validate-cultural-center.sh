#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cultural_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-cultural-validation.XXXXXX")
trap 'rm -rf "$cultural_validation_dir"' EXIT
xcrun swiftc -O Sources/ArchitectureEngine/SceneTypes.swift Sources/ArchitectureEngine/EiffelScene.swift \
  Sources/ArchitectureEngine/ParisEnvironment.swift Sources/ArchitectureEngine/RiverEnvironment.swift \
  Sources/ArchitectureEngine/NightLighting.swift Sources/ArchitectureEngine/CollisionWorld.swift \
  Sources/ArchitectureEngine/CulturalCenter.swift Tests/CulturalCenterGeometry/main.swift \
  -o "$cultural_validation_dir/validate"
"$cultural_validation_dir/validate"

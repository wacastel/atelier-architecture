#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
north_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-north-landmarks.XXXXXX")
trap 'rm -rf "$north_validation_dir"' EXIT
swiftc -O \
 Sources/ArchitectureEngine/SceneTypes.swift \
 Sources/ArchitectureEngine/EiffelScene.swift \
 Sources/ArchitectureEngine/ParisEnvironment.swift \
 Sources/ArchitectureEngine/RiverEnvironment.swift \
 Sources/ArchitectureEngine/NightLighting.swift \
 Sources/ArchitectureEngine/MillenniumEnvironment.swift \
 Sources/ArchitectureEngine/ChicagoEnvironment.swift Sources/ArchitectureEngine/NavyPierContext.swift \
 Sources/ArchitectureEngine/LakefrontEnvironment.swift \
 Sources/ArchitectureEngine/MuseumCampusEnvironment.swift \
 Sources/ArchitectureEngine/NorthSideEnvironment.swift \
 Sources/ArchitectureEngine/NorthSideLandmarks.swift \
 Sources/ArchitectureEngine/CollisionWorld.swift \
 Tests/NorthSideLandmarks/main.swift -o "$north_validation_dir/validate"
"$north_validation_dir/validate"

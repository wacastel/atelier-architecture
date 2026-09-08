#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
museum_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-museum-validation.XXXXXX")
trap 'rm -rf "$museum_validation_dir"' EXIT
swiftc -O \
 Sources/ArchitectureEngine/SceneTypes.swift \
 Sources/ArchitectureEngine/EiffelScene.swift \
 Sources/ArchitectureEngine/ParisEnvironment.swift \
 Sources/ArchitectureEngine/RiverEnvironment.swift \
 Sources/ArchitectureEngine/NightLighting.swift \
 Sources/ArchitectureEngine/MillenniumEnvironment.swift \
 Sources/ArchitectureEngine/ChicagoEnvironment.swift \
 Sources/ArchitectureEngine/LakefrontEnvironment.swift \
 Sources/ArchitectureEngine/MuseumCampusEnvironment.swift \
 Sources/ArchitectureEngine/SoldierField.swift \
 Tests/MuseumCampusGeometry/main.swift -o "$museum_validation_dir/validate"
"$museum_validation_dir/validate"

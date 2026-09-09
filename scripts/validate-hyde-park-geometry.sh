#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
hyde_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-hyde-validation.XXXXXX")
trap 'rm -rf "$hyde_validation_dir"' EXIT
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
 Sources/ArchitectureEngine/NorthSideEnvironment.swift \
 Sources/ArchitectureEngine/HydeParkEnvironment.swift \
 Tests/HydeParkGeometry/main.swift -o "$hyde_validation_dir/validate"
"$hyde_validation_dir/validate"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
navy_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-navy-validation.XXXXXX")
trap 'rm -rf "$navy_validation_dir"' EXIT
xcrun swiftc -O Sources/ArchitectureEngine/SceneTypes.swift Sources/ArchitectureEngine/EiffelScene.swift \
  Sources/ArchitectureEngine/ParisEnvironment.swift Sources/ArchitectureEngine/RiverEnvironment.swift \
  Sources/ArchitectureEngine/NightLighting.swift Sources/ArchitectureEngine/NavyPier.swift \
  Tests/NavyPierGeometry/main.swift -o "$navy_validation_dir/validate"
"$navy_validation_dir/validate"

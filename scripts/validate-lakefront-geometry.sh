#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
lakefront_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-lakefront-validation.XXXXXX")
trap 'rm -rf "$lakefront_validation_dir"' EXIT
swiftc -O \
  Sources/ArchitectureEngine/SceneTypes.swift \
  Sources/ArchitectureEngine/EiffelScene.swift \
  Sources/ArchitectureEngine/ParisEnvironment.swift \
  Sources/ArchitectureEngine/RiverEnvironment.swift \
  Sources/ArchitectureEngine/NightLighting.swift \
  Sources/ArchitectureEngine/MillenniumEnvironment.swift \
  Sources/ArchitectureEngine/ChicagoEnvironment.swift \
  Sources/ArchitectureEngine/LakefrontEnvironment.swift \
  Tests/LakefrontGeometry/main.swift \
  -o "$lakefront_validation_dir/validate"
"$lakefront_validation_dir/validate"

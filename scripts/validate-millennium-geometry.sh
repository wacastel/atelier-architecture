#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
millennium_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-millennium-validation.XXXXXX")
trap 'rm -rf "$millennium_validation_dir"' EXIT
swiftc -O \
  Sources/ArchitectureEngine/SceneTypes.swift \
  Sources/ArchitectureEngine/EiffelScene.swift \
  Sources/ArchitectureEngine/ParisEnvironment.swift \
  Sources/ArchitectureEngine/RiverEnvironment.swift \
  Sources/ArchitectureEngine/NightLighting.swift \
  Sources/ArchitectureEngine/MillenniumEnvironment.swift \
  Tests/MillenniumGeometry/main.swift \
  -o "$millennium_validation_dir/validate"
"$millennium_validation_dir/validate"

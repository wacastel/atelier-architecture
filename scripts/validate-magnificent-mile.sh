#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mile_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-mile-validation.XXXXXX")
trap 'rm -rf "$mile_validation_dir"' EXIT
swiftc -O \
  Sources/ArchitectureEngine/SceneTypes.swift \
  Sources/ArchitectureEngine/EiffelScene.swift \
  Sources/ArchitectureEngine/ParisEnvironment.swift \
  Sources/ArchitectureEngine/RiverEnvironment.swift \
  Sources/ArchitectureEngine/NightLighting.swift \
  Sources/ArchitectureEngine/MagnificentMile.swift \
  Tests/MagnificentMileGeometry/main.swift \
  -o "$mile_validation_dir/validate"
"$mile_validation_dir/validate"

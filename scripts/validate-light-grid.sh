#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
light_grid_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-light-grid-validation.XXXXXX")
trap 'rm -rf "$light_grid_validation_dir"' EXIT
swiftc -O \
  Sources/ArchitectureEngine/SceneTypes.swift \
  Sources/ArchitectureEngine/LightGrid.swift \
  Tests/LightGrid/main.swift \
  -o "$light_grid_validation_dir/validate"
"$light_grid_validation_dir/validate"

#!/bin/bash
set -euo pipefail
sunset_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sunset_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-sunset-lights.XXXXXX")"
trap 'rm -rf -- "$sunset_tmp"' EXIT
xcrun swiftc -O \
  "$sunset_project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/LightGrid.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/Traffic.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/RasterRenderer.swift" \
  "$sunset_project_dir/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$sunset_project_dir/Tests/SunsetLights/main.swift" \
  -o "$sunset_tmp/validate-sunset-lights"
if [[ "${1:-}" == "--build-only" ]]; then
  echo "PASS: Sunset-light fixture compiled; no Metal device or GPU work."
  exit 0
fi
(cd "$sunset_project_dir" && "$sunset_tmp/validate-sunset-lights")

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
raster_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-raster.XXXXXX")"
trap 'rm -rf -- "$raster_tmp"' EXIT
xcrun swiftc -O \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/LightGrid.swift" \
  "$project_dir/Sources/ArchitectureEngine/Traffic.swift" \
  "$project_dir/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$project_dir/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$project_dir/Sources/ArchitectureEngine/RasterRenderer.swift" \
  "$project_dir/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$project_dir/Tests/Raster/main.swift" \
  -o "$raster_tmp/validate-raster"
(cd "$project_dir" && "$raster_tmp/validate-raster" "$@")

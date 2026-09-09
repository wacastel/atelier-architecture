#!/bin/bash
set -euo pipefail
direct_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
direct_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-direct-ray.XXXXXX")"
trap 'rm -rf -- "$direct_tmp"' EXIT
xcrun swiftc -O \
  "$direct_project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/LightGrid.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/Traffic.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/RasterRenderer.swift" \
  "$direct_project_dir/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$direct_project_dir/Tests/DirectRay/main.swift" \
  -o "$direct_tmp/validate-direct-ray"
if [[ "${1:-}" == "--build-only" ]]; then
  echo "PASS: Direct-ray fixture compiled; no Metal device or GPU work."
  exit 0
fi
(cd "$direct_project_dir" && "$direct_tmp/validate-direct-ray" "$@")

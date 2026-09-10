#!/bin/bash
set -euo pipefail
startup_cache_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
startup_cache_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-startup-render-cache.XXXXXX")"
trap 'rm -rf -- "$startup_cache_tmp"' EXIT
xcrun swiftc -O \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/LightGrid.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/Traffic.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/RasterRenderer.swift" \
  "$startup_cache_project_dir/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$startup_cache_project_dir/Tests/StartupRenderCache/main.swift" \
  -o "$startup_cache_tmp/validate-startup-render-cache"
if [[ "${1:-}" == "--build-only" ]]; then
  echo "PASS: Startup renderer cache fixture compiled; no Metal device or GPU work."
  exit 0
fi
(cd "$startup_cache_project_dir" && "$startup_cache_tmp/validate-startup-render-cache")

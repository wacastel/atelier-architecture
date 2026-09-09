#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
paired_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-paired.XXXXXX")"
trap 'rm -rf -- "$paired_tmp"' EXIT
xcrun swiftc -O \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/LightGrid.swift" \
  "$project_dir/Sources/ArchitectureEngine/Traffic.swift" \
  "$project_dir/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$project_dir/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$project_dir/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$project_dir/Tests/PairedMotion/main.swift" \
  -o "$paired_tmp/validate-paired"
(cd "$project_dir" && "$paired_tmp/validate-paired")

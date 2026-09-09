#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
large_geometry_validation_dir=$(mktemp -d "${TMPDIR:-/tmp}/atelier-large-geometry.XXXXXX")
trap 'rm -rf "$large_geometry_validation_dir"' EXIT
swiftc -O Sources/ArchitectureEngine/SceneTypes.swift Sources/ArchitectureEngine/GeometryPartition.swift Tests/LargeGeometryGPU/main.swift -framework Metal -o "$large_geometry_validation_dir/validate"
"$large_geometry_validation_dir/validate" "$@"

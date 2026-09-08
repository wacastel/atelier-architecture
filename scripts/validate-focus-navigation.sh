#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
focus_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-focus-navigation.XXXXXX")"
trap 'rm -rf -- "$focus_tmp"' EXIT
# Only shared POD scene types, the existing collision BVH and focus primitives.
# The test uses tiny synthetic triangles plus offline map metadata, never a city build/GPU.
xcrun swiftc -O -whole-module-optimization \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/LandmarkFocus.swift" \
  "$project_dir/Tests/FocusNavigation/main.swift" \
  -o "$focus_tmp/validate-focus-navigation"
(cd "$project_dir" && "$focus_tmp/validate-focus-navigation")

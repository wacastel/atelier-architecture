#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
startup_loading_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-startup-loading.XXXXXX")"
trap 'rm -rf -- "$startup_loading_tmp"' EXIT
xcrun swiftc -O -whole-module-optimization \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/LandmarkFocus.swift" \
  "$project_dir/Sources/ArchitectureEngine/CityLoadingProgress.swift" \
  "$project_dir/Tests/StartupLoading/main.swift" \
  -o "$startup_loading_tmp/validate-startup-loading"
(cd "$project_dir" && "$startup_loading_tmp/validate-startup-loading")

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
focus_integration_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-focus-integration.XXXXXX")"
trap 'rm -rf -- "$focus_integration_tmp"' EXIT
scene_sources=(
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift"
  "$project_dir/Sources/ArchitectureEngine/EiffelScene.swift"
  "$project_dir/Sources/ArchitectureEngine/NightLighting.swift"
  "$project_dir/Sources/ArchitectureEngine/ArchitectureLocation.swift"
)
for scene_source in "$project_dir"/Sources/ArchitectureEngine/NorthSide*.swift "$project_dir"/Sources/ArchitectureEngine/LincolnPark*.swift "$project_dir"/Sources/ArchitectureEngine/WrigleyField*.swift "$project_dir"/Sources/ArchitectureEngine/Museum*.swift "$project_dir"/Sources/ArchitectureEngine/Adler*.swift "$project_dir"/Sources/ArchitectureEngine/Soldier*.swift "$project_dir"/Sources/ArchitectureEngine/McCormick*.swift "$project_dir"/Sources/ArchitectureEngine/Lakefront*.swift "$project_dir"/Sources/ArchitectureEngine/Magnificent*.swift "$project_dir"/Sources/ArchitectureEngine/Traffic.swift "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Willis*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift; do
  if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
done
xcrun swiftc -O -whole-module-optimization \
  "${scene_sources[@]}" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/Walkthrough.swift" \
  "$project_dir/Sources/ArchitectureEngine/LandmarkFocus.swift" \
  "$project_dir/Tests/FocusNavigationIntegration/main.swift" \
  -o "$focus_integration_tmp/validate-focus-navigation-integration"
(cd "$project_dir" && "$focus_integration_tmp/validate-focus-navigation-integration")

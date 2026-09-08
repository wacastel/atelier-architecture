#!/bin/bash
set -euo pipefail

# Exercise the production geometry and navigation BVH without launching the app.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
navigation_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-navigation.XXXXXX")"
trap 'rm -rf -- "$navigation_tmp"' EXIT

scene_sources=()
for scene_source in "$project_dir"/Sources/ArchitectureEngine/Museum*.swift "$project_dir"/Sources/ArchitectureEngine/Adler*.swift "$project_dir"/Sources/ArchitectureEngine/Soldier*.swift "$project_dir"/Sources/ArchitectureEngine/McCormick*.swift "$project_dir"/Sources/ArchitectureEngine/Lakefront*.swift "$project_dir"/Sources/ArchitectureEngine/Magnificent*.swift "$project_dir"/Sources/ArchitectureEngine/Traffic.swift "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift "$project_dir"/Sources/ArchitectureEngine/WillisScene.swift; do
  if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
done
xcrun swiftc -O -whole-module-optimization \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/EiffelScene.swift" \
  "$project_dir/Sources/ArchitectureEngine/NightLighting.swift" \
  "${scene_sources[@]}" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Tests/Navigation/main.swift" \
  -o "$navigation_tmp/validate-navigation"
(cd "$project_dir" && "$navigation_tmp/validate-navigation")

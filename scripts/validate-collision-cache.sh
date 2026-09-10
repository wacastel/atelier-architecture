#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
collision_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-collision-cache.XXXXXX")"
trap 'rm -rf -- "$collision_tmp"' EXIT
scene_sources=("$project_dir/Sources/ArchitectureEngine/SceneTypes.swift")
compile_flags=(-D COLLISION_CACHE_VALIDATION)
if [[ "${1:-}" == "--city" ]]; then
  compile_flags=(-D CITY_CACHE_VALIDATION)
  scene_sources+=("$project_dir/Sources/ArchitectureEngine/EiffelScene.swift" "$project_dir/Sources/ArchitectureEngine/NightLighting.swift" "$project_dir/Sources/ArchitectureEngine/ArchitectureLocation.swift")
  for scene_source in "$project_dir"/Sources/ArchitectureEngine/NavyPier*.swift "$project_dir"/Sources/ArchitectureEngine/CulturalCenter*.swift "$project_dir"/Sources/ArchitectureEngine/Skyline*.swift "$project_dir"/Sources/ArchitectureEngine/Robie*.swift "$project_dir"/Sources/ArchitectureEngine/HydePark*.swift "$project_dir"/Sources/ArchitectureEngine/NorthSide*.swift "$project_dir"/Sources/ArchitectureEngine/LincolnPark*.swift "$project_dir"/Sources/ArchitectureEngine/WrigleyField*.swift "$project_dir"/Sources/ArchitectureEngine/Museum*.swift "$project_dir"/Sources/ArchitectureEngine/Adler*.swift "$project_dir"/Sources/ArchitectureEngine/Soldier*.swift "$project_dir"/Sources/ArchitectureEngine/McCormick*.swift "$project_dir"/Sources/ArchitectureEngine/Lakefront*.swift "$project_dir"/Sources/ArchitectureEngine/Magnificent*.swift "$project_dir"/Sources/ArchitectureEngine/Traffic.swift "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Willis*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift; do
    if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
  done
  scene_sources+=("$project_dir/Sources/ArchitectureEngine/Walkthrough.swift" "$project_dir/Sources/ArchitectureEngine/LandmarkFocus.swift")
elif [[ -n "${1:-}" ]]; then
  printf 'Usage: %s [--city]\n' "$0" >&2
  exit 2
fi
xcrun swiftc -O -whole-module-optimization "${compile_flags[@]}" "${scene_sources[@]}" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Tests/CollisionCache/main.swift" \
  -o "$collision_tmp/validate-collision-cache"
(cd "$project_dir" && "$collision_tmp/validate-collision-cache")

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-cultural.XXXXXX")"
trap 'rm -rf -- "$benchmark_tmp"' EXIT
scene_sources=(
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift"
  "$project_dir/Sources/ArchitectureEngine/EiffelScene.swift"
  "$project_dir/Sources/ArchitectureEngine/NightLighting.swift"
  "$project_dir/Sources/ArchitectureEngine/ArchitectureLocation.swift"
)
for scene_source in "$project_dir"/Sources/ArchitectureEngine/CulturalCenter*.swift "$project_dir"/Sources/ArchitectureEngine/Skyline*.swift "$project_dir"/Sources/ArchitectureEngine/Robie*.swift "$project_dir"/Sources/ArchitectureEngine/HydePark*.swift "$project_dir"/Sources/ArchitectureEngine/NorthSide*.swift "$project_dir"/Sources/ArchitectureEngine/LincolnPark*.swift "$project_dir"/Sources/ArchitectureEngine/WrigleyField*.swift "$project_dir"/Sources/ArchitectureEngine/Museum*.swift "$project_dir"/Sources/ArchitectureEngine/Adler*.swift "$project_dir"/Sources/ArchitectureEngine/Soldier*.swift "$project_dir"/Sources/ArchitectureEngine/McCormick*.swift "$project_dir"/Sources/ArchitectureEngine/Lakefront*.swift "$project_dir"/Sources/ArchitectureEngine/Magnificent*.swift "$project_dir"/Sources/ArchitectureEngine/Traffic.swift "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Willis*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift; do
  if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
done

scene_sources+=(
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift"
  "$project_dir/Sources/ArchitectureEngine/Walkthrough.swift"
  "$project_dir/Sources/ArchitectureEngine/LightGrid.swift"
  "$project_dir/Sources/ArchitectureEngine/TrafficMetal.swift"
  "$project_dir/Sources/ArchitectureEngine/GeometryPartition.swift"
  "$project_dir/Sources/ArchitectureEngine/RasterRenderer.swift"
  "$project_dir/Sources/ArchitectureEngine/MetalRenderer.swift"
  "$project_dir/Sources/ArchitectureEngine/LandmarkFocus.swift"
  "$project_dir/Sources/ArchitectureEngine/ManualCityNavigation.swift"
  "$project_dir/Tests/CulturalCenterRendering/main.swift"
)
printf '%s\n' "${scene_sources[@]}" "$project_dir/scripts/validate-cultural-center-rendering.sh" "$project_dir"/Sources/ArchitectureEngine/Resources/*.metal "$project_dir"/Sources/ArchitectureEngine/Resources/{Chicago,HydePark,Lakefront,Millennium,MuseumCampus,NorthSide,Paris}/*.json > "$benchmark_tmp/inputs.txt"
xcrun swiftc -O -whole-module-optimization "${scene_sources[@]}" -o "$benchmark_tmp/cultural-rendering"
(cd "$project_dir" && ATELIER_BENCHMARK_INPUTS="$benchmark_tmp/inputs.txt" "$benchmark_tmp/cultural-rendering" "$@")

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
gateway_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-gateway.XXXXXX")"
trap 'rm -rf -- "$gateway_tmp"' EXIT
# ChicagoContext's production decoder shares a file with city construction;
# compile its real scene dependencies without initializing or rendering a city.
scene_sources=(
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift"
  "$project_dir/Sources/ArchitectureEngine/EiffelScene.swift"
  "$project_dir/Sources/ArchitectureEngine/NightLighting.swift"
  "$project_dir/Sources/ArchitectureEngine/ArchitectureLocation.swift"
)
for scene_source in "$project_dir"/Sources/ArchitectureEngine/Skyline*.swift "$project_dir"/Sources/ArchitectureEngine/Robie*.swift "$project_dir"/Sources/ArchitectureEngine/HydePark*.swift "$project_dir"/Sources/ArchitectureEngine/NorthSide*.swift "$project_dir"/Sources/ArchitectureEngine/LincolnPark*.swift "$project_dir"/Sources/ArchitectureEngine/WrigleyField*.swift "$project_dir"/Sources/ArchitectureEngine/Museum*.swift "$project_dir"/Sources/ArchitectureEngine/Adler*.swift "$project_dir"/Sources/ArchitectureEngine/Soldier*.swift "$project_dir"/Sources/ArchitectureEngine/McCormick*.swift "$project_dir"/Sources/ArchitectureEngine/Lakefront*.swift "$project_dir"/Sources/ArchitectureEngine/Magnificent*.swift "$project_dir"/Sources/ArchitectureEngine/Traffic.swift "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Willis*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift; do
  if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
done
xcrun swiftc -O -whole-module-optimization \
  "${scene_sources[@]}" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/Walkthrough.swift" \
  "$project_dir/Tests/MagnificentGateway/main.swift" \
  -o "$gateway_tmp/validate-gateway"
(cd "$project_dir" && "$gateway_tmp/validate-gateway")

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
playback_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-playback.XXXXXX")"
trap 'rm -rf -- "$playback_tmp"' EXIT
scene_sources=(
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift"
  "$project_dir/Sources/ArchitectureEngine/EiffelScene.swift"
  "$project_dir/Sources/ArchitectureEngine/NightLighting.swift"
  "$project_dir/Sources/ArchitectureEngine/ArchitectureLocation.swift"
)
for scene_source in "$project_dir"/Sources/ArchitectureEngine/Millennium*.swift "$project_dir"/Sources/ArchitectureEngine/ArtInstitute.swift "$project_dir"/Sources/ArchitectureEngine/CameraTrack.swift "$project_dir"/Sources/ArchitectureEngine/Paris*.swift "$project_dir"/Sources/ArchitectureEngine/River*.swift "$project_dir"/Sources/ArchitectureEngine/Willis*.swift "$project_dir"/Sources/ArchitectureEngine/Chicago*.swift; do
  if [[ -f "$scene_source" ]]; then scene_sources+=("$scene_source"); fi
done
xcrun swiftc -O -whole-module-optimization \
  "${scene_sources[@]}" \
  "$project_dir/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$project_dir/Sources/ArchitectureEngine/Walkthrough.swift" \
  "$project_dir/Tests/Playback/main.swift" \
  -o "$playback_tmp/validate-playback"
(cd "$project_dir" && "$playback_tmp/validate-playback")

#!/bin/bash
set -euo pipefail
zoo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
zoo_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-zoo.XXXXXX")"
trap 'rm -rf -- "$zoo_tmp"' EXIT
awk '/^final class EiffelBuilder/{body=1} body{print}' "$zoo_root/Sources/ArchitectureEngine/EiffelScene.swift" > "$zoo_tmp/BuilderBody.swift"
{ echo 'import Foundation'; echo 'import simd'; cat "$zoo_tmp/BuilderBody.swift"; } > "$zoo_tmp/EiffelBuilder.swift"
xcrun swiftc -O "$zoo_root/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$zoo_tmp/EiffelBuilder.swift" "$zoo_root/Sources/ArchitectureEngine/NightLighting.swift" \
  "$zoo_root/Sources/ArchitectureEngine/LincolnParkZooMap.swift" \
  "$zoo_root/Sources/ArchitectureEngine/LincolnParkZoo.swift" \
  "$zoo_root/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$zoo_root/Tests/LincolnParkZoo/main.swift" -o "$zoo_tmp/validate-zoo"
"$zoo_tmp/validate-zoo" "$@"

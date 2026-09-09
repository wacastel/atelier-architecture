#!/bin/bash
set -euo pipefail
adler_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
adler_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-adler.XXXXXX")"
trap 'rm -rf -- "$adler_tmp"' EXIT
# Compile the actual builder class verbatim, excluding only the file's separate
# EiffelScene entry point so this isolated fixture need not build every city.
awk '/^final class EiffelBuilder/{body=1} body{print}' "$adler_root/Sources/ArchitectureEngine/EiffelScene.swift" > "$adler_tmp/BuilderBody.swift"
{ echo 'import Foundation'; echo 'import simd'; cat "$adler_tmp/BuilderBody.swift"; } > "$adler_tmp/EiffelBuilder.swift"
xcrun swiftc -O "$adler_root/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$adler_tmp/EiffelBuilder.swift" "$adler_root/Sources/ArchitectureEngine/NightLighting.swift" \
  "$adler_root/Sources/ArchitectureEngine/AdlerPlanetarium.swift" \
  "$adler_root/Sources/ArchitectureEngine/CollisionWorld.swift" \
  "$adler_root/Sources/ArchitectureEngine/LightGrid.swift" \
  "$adler_root/Sources/ArchitectureEngine/Traffic.swift" \
  "$adler_root/Sources/ArchitectureEngine/TrafficMetal.swift" \
  "$adler_root/Sources/ArchitectureEngine/GeometryPartition.swift" \
  "$adler_root/Sources/ArchitectureEngine/RasterRenderer.swift" "$adler_root/Sources/ArchitectureEngine/MetalRenderer.swift" \
  "$adler_root/Tests/Adler/ProjectionReconstruction.swift" \
  "$adler_root/Tests/Adler/main.swift" -o "$adler_tmp/validate-adler"
"$adler_tmp/validate-adler" "$@"

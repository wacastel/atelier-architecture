#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
map_integration_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-map-integration.XXXXXX")"
trap 'rm -rf -- "$map_integration_tmp"' EXIT

# Compile the actual controller and its production dependencies. Exclude the
# app/CLI entry points and replace only the audio type with the inert fixture
# stub. Linking Metal is required by the controller; the test never requests a
# device, attaches a view, builds city geometry, or constructs the renderer.
map_sources=()
for source in "$project_dir"/Sources/ArchitectureEngine/*.swift; do
  case "${source##*/}" in
    ArchitectureApp.swift|CommandLine.swift|AmbientMusic.swift|MotionValidation.swift) ;;
    *) map_sources+=("$source") ;;
  esac
done
xcrun swiftc -O -whole-module-optimization \
  "${map_sources[@]}" "$project_dir/Tests/MapModeIntegration/main.swift" \
  -framework Metal -framework MetalKit -framework AppKit -framework SwiftUI \
  -o "$map_integration_tmp/validate-map-mode-integration"
(cd "$project_dir" && "$map_integration_tmp/validate-map-mode-integration")

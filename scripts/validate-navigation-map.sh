#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
map_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-navigation-map.XXXXXX")"
trap 'rm -rf -- "$map_tmp"' EXIT
xcrun swiftc -O -swift-version 5 -parse-as-library \
  "$project_dir/Sources/ArchitectureEngine/NavigationMap.swift" \
  "$project_dir/Tests/NavigationMap/main.swift" \
  -o "$map_tmp/validate-navigation-map"
(cd "$project_dir" && "$map_tmp/validate-navigation-map")

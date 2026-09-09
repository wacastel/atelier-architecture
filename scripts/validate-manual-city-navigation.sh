#!/bin/bash
set -euo pipefail
navigation_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
navigation_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-city-navigation.XXXXXX")"
trap 'rm -rf -- "$navigation_tmp"' EXIT
xcrun swiftc -O "$navigation_root/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$navigation_root/Sources/ArchitectureEngine/ManualCityNavigation.swift" \
  "$navigation_root/Tests/ManualCityNavigation/main.swift" -o "$navigation_tmp/validate"
"$navigation_tmp/validate"

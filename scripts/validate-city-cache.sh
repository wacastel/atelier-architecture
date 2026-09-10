#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
city_cache_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-city-cache.XXXXXX")"
trap 'rm -rf -- "$city_cache_tmp"' EXIT
xcrun swiftc -O -whole-module-optimization \
  "$project_dir/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$project_dir/Sources/ArchitectureEngine/CityCache.swift" \
  "$project_dir/Tests/CityCache/main.swift" \
  -o "$city_cache_tmp/validate-city-cache"
(cd "$project_dir" && "$city_cache_tmp/validate-city-cache")

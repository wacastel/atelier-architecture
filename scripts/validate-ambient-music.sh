#!/bin/bash
set -euo pipefail
music_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
music_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-music-test.XXXXXX")"
trap 'rm -rf -- "$music_tmp"' EXIT
cd "$music_root"
xcrun swiftc -O Sources/ArchitectureEngine/AmbientMusic.swift Tests/AmbientMusic/main.swift \
  -framework AVFoundation -framework Combine -o "$music_tmp/validate"
"$music_tmp/validate" "$@"

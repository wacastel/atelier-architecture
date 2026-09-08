#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
viewport_input_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-viewport-input.XXXXXX")"
trap 'rm -rf -- "$viewport_input_tmp"' EXIT
xcrun swiftc -O \
  "$project_dir/Sources/ArchitectureEngine/ViewportPointerGesture.swift" \
  "$project_dir/Tests/ViewportInput/main.swift" \
  -o "$viewport_input_tmp/validate-viewport-input"
"$viewport_input_tmp/validate-viewport-input" "$@"

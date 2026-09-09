#!/bin/bash
set -euo pipefail
presentation_project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
presentation_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-direct-presentation.XXXXXX")"
trap 'rm -rf -- "$presentation_tmp"' EXIT
xcrun swiftc -O "$presentation_project/Sources/ArchitectureEngine/SceneTypes.swift" \
  "$presentation_project/Tests/DirectPresentation/main.swift" -o "$presentation_tmp/validate-direct-presentation"
if [[ "${1:-}" == "--build-only" ]]; then
  echo "PASS: Presentation oracle compiled; no GPU work."
  exit 0
fi
# Compare the untouched legacy presentation against the preceding committed
# source, not a copied implementation or a new mathematical approximation.
git -C "$presentation_project" show HEAD:Sources/ArchitectureEngine/Resources/Renderer.metal > "$presentation_tmp/legacy-renderer.metal"
(cd "$presentation_project" && "$presentation_tmp/validate-direct-presentation" "$presentation_tmp/legacy-renderer.metal")

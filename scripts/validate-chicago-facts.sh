#!/bin/bash
set -euo pipefail
atelier_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
atelier_facts_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-facts.XXXXXX")"
trap 'rm -rf -- "$atelier_facts_tmp"' EXIT
xcrun swiftc -O "$atelier_project_dir/Sources/ArchitectureEngine/ChicagoFacts.swift" \
    "$atelier_project_dir/Tests/ChicagoFacts/main.swift" -o "$atelier_facts_tmp/validate-facts"
"$atelier_facts_tmp/validate-facts"

#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
metrics_tmp="$(mktemp -d "${TMPDIR:-/tmp}/atelier-startup-metrics.XXXXXX")"
trap 'rm -rf -- "$metrics_tmp"' EXIT
xcrun swiftc -O -whole-module-optimization \
  "$project_dir/Sources/ArchitectureEngine/StartupMetrics.swift" \
  "$project_dir/Tests/StartupMetrics/main.swift" \
  -o "$metrics_tmp/validate-startup-metrics"
"$metrics_tmp/validate-startup-metrics" --startup-report "$metrics_tmp/startup.json"

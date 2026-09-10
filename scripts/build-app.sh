#!/bin/bash
set -euo pipefail

# Build a relocatable, locally signed application without installing anything.
atelier_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
atelier_swift="$(/usr/bin/xcrun --find swift)"
atelier_app="$atelier_project_dir/dist/Atelier.app"
atelier_precache_city=chicago
atelier_precache=true
atelier_cache_args=()

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --no-precache) atelier_precache=false; shift ;;
        --precache-city)
            [[ "$#" -ge 2 && "$2" =~ ^(chicago|paris|all)$ ]] || { echo "--precache-city requires chicago, paris or all." >&2; exit 2; }
            atelier_precache_city="$2"; shift 2 ;;
        --cache-dir)
            [[ "$#" -ge 2 && -n "$2" && "$2" != --* ]] || { echo "--cache-dir requires a directory." >&2; exit 2; }
            atelier_cache_args+=(--cache-dir "$2"); shift 2 ;;
        --force-rebuild-cache) atelier_cache_args+=(--force-rebuild-cache); shift ;;
        --help|-h)
            cat <<'HELP'
Build, sign and precache Atelier for Apple Silicon.

Usage: ./scripts/build-app.sh [options]
  --precache-city chicago|paris|all  World to prepare (default chicago)
  --no-precache                     Package only, for development or baseline measurement
  --cache-dir DIRECTORY             Use an alternate cache directory
  --force-rebuild-cache             Rebuild even if this executable already has a valid cache

The default prepares the shared Chicago world before replacing dist/Atelier.app.
It does not open a window. A failed build or precache keeps the previous app.
HELP
            exit 0 ;;
        *) echo "Unknown build option: $1. Use --help." >&2; exit 2 ;;
    esac
done
if [[ "$atelier_precache" == false && "${#atelier_cache_args[@]}" -gt 0 ]]; then
    echo "Cache options cannot be combined with --no-precache." >&2
    exit 2
fi

if [[ "$(/usr/bin/uname -m)" != "arm64" ]]; then
    echo "Atelier targets native Apple Silicon. Run this script from an arm64 terminal." >&2
    exit 1
fi

echo "Building Atelier for Apple Silicon…"
"$atelier_swift" build --package-path "$atelier_project_dir" --configuration release --arch arm64
atelier_bin_dir="$("$atelier_swift" build --package-path "$atelier_project_dir" --configuration release --arch arm64 --show-bin-path)"
atelier_bundle="ArchitectureEngine_ArchitectureEngine.bundle"
[[ -x "$atelier_bin_dir/ArchitectureEngine" ]] || { echo "Release executable is missing." >&2; exit 1; }
[[ -f "$atelier_bin_dir/$atelier_bundle/Resources/Renderer.metal" && -f "$atelier_bin_dir/$atelier_bundle/Resources/Denoise.metal" && -f "$atelier_bin_dir/$atelier_bundle/Resources/Raster.metal" && -f "$atelier_bin_dir/$atelier_bundle/Resources/DirectRay.metal" ]] || { echo "Metal shader resource bundle is missing." >&2; exit 1; }

/bin/mkdir -p "$atelier_project_dir/dist"
atelier_stage_dir="$(/usr/bin/mktemp -d "$atelier_project_dir/dist/.atelier-build.XXXXXX")"
trap '/bin/rm -rf "$atelier_stage_dir"' EXIT
atelier_staged_app="$atelier_stage_dir/Atelier.app"
/bin/mkdir -p "$atelier_staged_app/Contents/MacOS" "$atelier_staged_app/Contents/Resources"
/bin/cp "$atelier_bin_dir/ArchitectureEngine" "$atelier_staged_app/Contents/MacOS/ArchitectureEngine"
/usr/bin/ditto "$atelier_bin_dir/$atelier_bundle" "$atelier_staged_app/Contents/Resources/$atelier_bundle"
/bin/cp "$atelier_project_dir/assets/Atelier.icns" "$atelier_staged_app/Contents/Resources/Atelier.icns"

/bin/cat > "$atelier_staged_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>ArchitectureEngine</string>
    <key>CFBundleIdentifier</key><string>local.atelier.architecture</string>
    <key>CFBundleName</key><string>Atelier</string>
    <key>CFBundleDisplayName</key><string>Atelier</string>
    <key>CFBundleIconFile</key><string>Atelier.icns</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>2.7.0</string>
    <key>CFBundleVersion</key><string>22</string>
    <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSArchitecturePriority</key><array><string>arm64</string></array>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$atelier_staged_app/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$atelier_staged_app"
/usr/bin/codesign --verify --deep --strict "$atelier_staged_app"

# Precache the signed bytes that will actually launch. Moving this app into
# place below does not change its executable/resource identity or its cache key.
if [[ "$atelier_precache" == true ]]; then
    echo "Preparing $atelier_precache_city for the next launch…"
    "$atelier_staged_app/Contents/MacOS/ArchitectureEngine" \
        --precache-city "$atelier_precache_city" \
        --cache-report "$atelier_stage_dir/precache-report.json" \
        "${atelier_cache_args[@]+${atelier_cache_args[@]}}"
fi

# Replace only the generated app after the complete replacement has validated.
if [[ -e "$atelier_app" ]]; then
    /bin/mv "$atelier_app" "$atelier_stage_dir/previous.app"
fi
if ! /bin/mv "$atelier_staged_app" "$atelier_app"; then
    if [[ -e "$atelier_stage_dir/previous.app" ]]; then
        /bin/mv "$atelier_stage_dir/previous.app" "$atelier_app"
    fi
    exit 1
fi
if [[ -f "$atelier_stage_dir/precache-report.json" ]]; then
    /bin/mv "$atelier_stage_dir/precache-report.json" "$atelier_project_dir/dist/precache-report.json"
elif [[ -f "$atelier_project_dir/dist/precache-report.json" ]]; then
    /bin/rm "$atelier_project_dir/dist/precache-report.json"
fi
echo "Built $atelier_app"

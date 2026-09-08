#!/bin/bash
set -euo pipefail

# Build a relocatable, locally signed application without installing anything.
atelier_project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
atelier_swift="$(/usr/bin/xcrun --find swift)"
atelier_app="$atelier_project_dir/dist/Atelier.app"

if [[ "$(/usr/bin/uname -m)" != "arm64" ]]; then
    echo "Atelier targets native Apple Silicon. Run this script from an arm64 terminal." >&2
    exit 1
fi

echo "Building Atelier for Apple Silicon…"
"$atelier_swift" build --package-path "$atelier_project_dir" --configuration release --arch arm64
atelier_bin_dir="$("$atelier_swift" build --package-path "$atelier_project_dir" --configuration release --arch arm64 --show-bin-path)"
atelier_bundle="ArchitectureEngine_ArchitectureEngine.bundle"
[[ -x "$atelier_bin_dir/ArchitectureEngine" ]] || { echo "Release executable is missing." >&2; exit 1; }
[[ -f "$atelier_bin_dir/$atelier_bundle/Resources/Renderer.metal" && -f "$atelier_bin_dir/$atelier_bundle/Resources/Denoise.metal" ]] || { echo "Metal shader resource bundle is missing." >&2; exit 1; }

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
    <key>CFBundleShortVersionString</key><string>1.8.0</string>
    <key>CFBundleVersion</key><string>9</string>
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
echo "Built $atelier_app"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
swift build -c "$configuration" --product OTPBar -Xswiftc -warnings-as-errors
binary_dir="$(swift build -c "$configuration" --show-bin-path)"
app=".build/app/OTPBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/OTPBar" "$app/Contents/MacOS/OTPBar"
cp assets/icon/OTPBar.icns "$app/Contents/Resources/OTPBar.icns"
cp assets/icon/otpbar-template.png assets/icon/otpbar-template@2x.png "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>OTPBar</string>
<key>CFBundleIdentifier</key><string>com.erugihs.otpbar</string>
<key>CFBundleName</key><string>OTPBar</string>
<key>CFBundleDisplayName</key><string>OTPBar</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>OTPBar</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.erugihs.otpbar "$app"
codesign --verify --strict "$app"
printf 'Built %s\n' "$app"

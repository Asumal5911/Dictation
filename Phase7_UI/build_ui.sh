#!/bin/bash
set -e

APP_NAME="Dictation"
BUNDLE_ID="com.macdictation.ui"

echo "Building SwiftUI MenuBar App..."

# Create Directories
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Compile Swift files
swiftc DictationApp.swift MenuView.swift FloatingDictationView.swift -o "$APP_NAME.app/Contents/MacOS/$APP_NAME" -target arm64-apple-macosx13.0

# Create Info.plist (LSUIElement=true hides the dock icon for menu bar apps)
cat <<EOF > "$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing app..."
codesign --force --sign - "$APP_NAME.app/Contents/MacOS/$APP_NAME"

echo "Build complete. Launching $APP_NAME.app..."
open "$APP_NAME.app"

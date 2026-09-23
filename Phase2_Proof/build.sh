#!/bin/bash
set -e

APP_NAME="DictationUI"
BUNDLE_ID="com.macdictation.ui"
AGENT_NAME="com.macdictation.recorder"
AGENT_BUNDLE_ID="com.macdictation.recorder"

echo "Building App Bundle for Phase 2 Minimal Proof..."

# Create Directories
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Library/LaunchAgents"

# Compile Shared + Agent
swiftc Shared.swift RecorderAgent.swift -o "$APP_NAME.app/Contents/Library/LaunchAgents/$AGENT_NAME"

# Compile Shared + Client
swiftc Shared.swift ClientApp.swift -o "$APP_NAME.app/Contents/MacOS/$APP_NAME"

# Create UI App Info.plist
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
    <key>NSMicrophoneUsageDescription</key>
    <string>Dictation requires microphone access to record audio.</string>
</dict>
</plist>
EOF

# Create Agent Launch .plist
cat <<EOF > "$APP_NAME.app/Contents/Library/LaunchAgents/$AGENT_NAME.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$AGENT_BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>Contents/Library/LaunchAgents/$AGENT_NAME</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>$AGENT_BUNDLE_ID</key>
        <true/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

# Entitlements for Sandbox and Microphone
cat <<EOF > entitlements.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
EOF

echo "Signing binaries..."
codesign --force --sign - --entitlements entitlements.plist -o runtime "$APP_NAME.app/Contents/Library/LaunchAgents/$AGENT_NAME"
codesign --force --sign - --entitlements entitlements.plist -o runtime "$APP_NAME.app/Contents/MacOS/$APP_NAME"

echo "Build complete. To test the proof of concept:"
echo "1. Run the Launch Agent directly to prompt for mic permissions:"
echo "   ./$APP_NAME.app/Contents/Library/LaunchAgents/$AGENT_NAME &"
echo "2. Run the Client App to trigger it via XPC:"
echo "   ./$APP_NAME.app/Contents/MacOS/$APP_NAME"

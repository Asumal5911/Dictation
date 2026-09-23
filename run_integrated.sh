#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Mac Local Dictation ==="

# Check Python environment
if ! command -v python3 &> /dev/null; then
    echo "Python 3 is required."
    exit 1
fi

# Ensure Homebrew path is present for ffmpeg
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "Checking Backend Server..."
if curl -s http://127.0.0.1:8080/health | grep -q "status"; then
    echo "✅ Backend server is already running and responsive."
else
    echo "Starting Backend Server..."
    cd "$DIR/Backend"
    python3 server.py &
    BACKEND_PID=$!
    sleep 3
fi

echo "Building & Installing Dictation UI..."
cd "$DIR/UI"
./build_ui.sh

echo ""
echo "================================================="
echo "The Dictation UI is now running!"
echo "1. Look for the floating pill in the bottom right."
echo "2. Click any text field (e.g. Notes, Pages, Browser)."
echo "3. Tap the 'Fn' button (or click the microphone icon) to start."
echo "4. Speak or take lecture notes."
echo "5. Tap 'Fn' again (or click the Checkmark) when done."
echo "6. Notes will be transcribed and instantly pasted back!"
echo "================================================="
echo ""

if [ -n "$BACKEND_PID" ]; then
    echo "Press Ctrl+C to terminate backend server process..."
    wait $BACKEND_PID
fi

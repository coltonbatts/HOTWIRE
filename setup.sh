#!/bin/bash

echo "===================================="
echo "Canon 6D Mark II Controller Setup"
echo "===================================="
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not found"
    echo "📥 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == 'arm64' ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "✅ Homebrew found"
fi

echo ""

# Check if gphoto2 is installed
if ! command -v gphoto2 &> /dev/null; then
    echo "❌ gphoto2 not found"
    echo "📥 Installing gphoto2..."
    brew install gphoto2
else
    echo "✅ gphoto2 found"
    gphoto2 --version
fi

echo ""
echo "===================================="
echo "Testing Camera Connection"
echo "===================================="
echo ""

# Kill PTPCamera daemon
echo "🔄 Killing PTPCamera daemon..."
killall PTPCamera 2>/dev/null
sleep 1

# Check for camera
echo "🔍 Scanning for Canon camera..."
if gphoto2 --auto-detect | grep -q "Canon"; then
    echo "✅ Canon camera detected!"
    echo ""
    echo "📸 Camera Summary:"
    gphoto2 --summary
else
    echo "❌ No Canon camera detected"
    echo ""
    echo "⚠️  Troubleshooting Checklist:"
    echo "   1. Is WiFi DISABLED on the camera?"
    echo "   2. Is the USB cable connected?"
    echo "   3. Is the camera powered ON?"
    echo "   4. Is the camera in Manual mode (M)?"
    echo ""
    echo "Run this script again after checking the above."
fi

echo ""
echo "===================================="
echo "Next Steps"
echo "===================================="
echo ""
echo "1. Open project in Xcode:"
echo "   swift package generate-xcodeproj"
echo "   open CanonCameraController.xcodeproj"
echo ""
echo "2. Or build with Swift:"
echo "   swift build"
echo "   swift run"
echo ""
echo "📖 See README.md for detailed instructions"
echo ""

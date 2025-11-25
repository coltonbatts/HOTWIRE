#!/bin/bash

# Hotwire Build Script
# Builds the app and creates a proper macOS app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Hotwire"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
BUNDLE_ID="com.hotwire.app"
VERSION="1.0.0"

echo "🔨 Building $APP_NAME..."

# Build the release version
cd "$SCRIPT_DIR"
swift build -c release

echo "📦 Creating app bundle..."

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy the executable
cp "$SCRIPT_DIR/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create PkgInfo file
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Hotwire needs camera access for tethered shooting.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create a simple app icon using sips (built into macOS)
echo "🎨 Creating app icon..."

ICON_DIR="$SCRIPT_DIR/AppIcon.iconset"
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"

# Create a simple PNG icon using printf and base64 (a camera-like icon)
# We'll create a temporary icon using ImageMagick if available, or a colored square
if command -v convert &> /dev/null; then
    # ImageMagick available - create a nice icon
    convert -size 1024x1024 xc:'#1a1a2e' \
        -fill '#e94560' -draw "circle 512,512 512,200" \
        -fill '#0f3460' -draw "circle 512,512 512,350" \
        -fill '#e94560' -draw "circle 512,512 512,450" \
        -fill white -pointsize 200 -gravity center -annotate 0 "H" \
        "$ICON_DIR/icon_512x512@2x.png" 2>/dev/null || true
fi

# If we don't have a proper icon, create using built-in tools
if [ ! -f "$ICON_DIR/icon_512x512@2x.png" ]; then
    # Create a simple colored square icon using Python (available on all Macs)
    python3 << 'PYTHON_SCRIPT'
import os
import struct
import zlib

def create_png(width, height, color_rgb):
    """Create a simple solid color PNG."""
    def make_chunk(chunk_type, data):
        chunk = chunk_type + data
        crc = zlib.crc32(chunk) & 0xffffffff
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', crc)
    
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    ihdr = make_chunk(b'IHDR', ihdr_data)
    
    # IDAT chunk (image data)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # filter byte
        for x in range(width):
            # Create a gradient effect
            cx, cy = width // 2, height // 2
            dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            max_dist = (cx ** 2 + cy ** 2) ** 0.5
            factor = 1 - (dist / max_dist) * 0.3
            r = min(255, int(color_rgb[0] * factor))
            g = min(255, int(color_rgb[1] * factor))
            b = min(255, int(color_rgb[2] * factor))
            raw_data += bytes([r, g, b])
    
    compressed = zlib.compress(raw_data, 9)
    idat = make_chunk(b'IDAT', compressed)
    
    # IEND chunk
    iend = make_chunk(b'IEND', b'')
    
    return signature + ihdr + idat + iend

# Hotwire brand color - electric red/orange
color = (233, 69, 96)  # #E94560

sizes = [16, 32, 64, 128, 256, 512, 1024]
iconset_dir = os.environ.get('ICON_DIR', 'AppIcon.iconset')

for size in sizes:
    png_data = create_png(size, size, color)
    
    # Regular size
    if size <= 512:
        with open(f"{iconset_dir}/icon_{size}x{size}.png", 'wb') as f:
            f.write(png_data)
    
    # @2x size (half the pixel size name)
    if size >= 32:
        half = size // 2
        with open(f"{iconset_dir}/icon_{half}x{half}@2x.png", 'wb') as f:
            f.write(png_data)

print("Icon PNGs created")
PYTHON_SCRIPT
fi

# Convert iconset to icns
if [ -d "$ICON_DIR" ] && ls "$ICON_DIR"/*.png 1> /dev/null 2>&1; then
    iconutil -c icns "$ICON_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || {
        echo "⚠️  Could not create .icns file (icon will use default)"
    }
    rm -rf "$ICON_DIR"
fi

# Make the executable... executable
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Touch the app to update Finder
touch "$APP_BUNDLE"

echo ""
echo "✅ Build complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App bundle created at:"
echo "  $APP_BUNDLE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📁 Drag to /Applications to install"
echo "  🖱️  Or double-click to run now!"
echo ""

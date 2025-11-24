# Quick Start Guide

Get your Canon 6D Mark II controller running in 5 minutes.

## Prerequisites Checklist

Before starting, ensure:

- [ ] You have a Mac with macOS 14.0 or later
- [ ] Canon 6D Mark II camera with USB cable
- [ ] Xcode 15.0+ installed (download from App Store if needed)

## Setup Steps

### 1. Run the Setup Script

Open Terminal and navigate to this directory, then run:

```bash
cd /Users/coltonbatts/Desktop/test
chmod +x setup.sh
./setup.sh
```

This script will:
- Install Homebrew (if needed)
- Install gphoto2
- Test your camera connection

### 2. Prepare Your Camera

**CRITICAL**: Disable WiFi on your camera first!

1. Turn on your Canon 6D Mark II
2. Press `MENU` button
3. Navigate to **Wireless settings**
4. Select **Disable** for WiFi
5. Set camera to **Manual mode** (turn dial to `M`)
6. Connect USB cable between camera and Mac

### 3. Kill PTPCamera Daemon

Every time you connect the camera, run this in Terminal:

```bash
killall PTPCamera
```

### 4. Build and Run

#### Option A: Using Xcode (Recommended)

```bash
# Generate Xcode project
swift package generate-xcodeproj

# Open in Xcode
open CanonCameraController.xcodeproj
```

Then press `⌘R` to build and run.

#### Option B: Command Line

```bash
# Build
swift build

# Run
swift run
```

## First Use

1. Launch the application
2. You'll see connection status at the top
3. Click **"Scan for Camera"**
4. If connected, you'll see a green indicator
5. Click **"Start Live View"** to see camera preview
6. Click **"Capture"** to take a photo

## Troubleshooting

### Camera Not Detected

Run these commands in order:

```bash
# 1. Kill PTPCamera
killall PTPCamera

# 2. Check if camera is connected via USB
system_profiler SPUSBDataType | grep -i canon

# 3. Test with gphoto2 directly
gphoto2 --auto-detect
```

If still not working:
- ✓ Is WiFi **completely disabled** on camera?
- ✓ Is camera in **Manual mode** (not Auto)?
- ✓ Try a different USB port (use Thunderbolt directly)
- ✓ Try a different USB cable

### Build Errors in Xcode

If you get "Platform not found" or similar:
1. Make sure you're targeting **macOS** (not iOS)
2. Select "My Mac" as the run destination
3. Set minimum deployment target to macOS 14.0

### Permission Errors

Grant permissions when prompted:
- **USB Device Access**: Required for camera communication
- **Files and Folders**: If you want to save photos to specific locations

## What's Next?

Once you have the basic app running:

1. **Test Live View**: Verify the preview shows your camera's view
2. **Test Capture**: Take a few photos to ensure it works
3. **Try Settings**: Change ISO, aperture, and shutter speed
4. **Check Output**: Photos are saved to the current directory

## Need Help?

1. Check the full [README.md](README.md) for detailed documentation
2. Review [CLAUDE.MD](CLAUDE.MD) for technical context
3. Test gphoto2 directly: `gphoto2 --summary`

## Common Commands Reference

```bash
# Install/update gphoto2
brew install gphoto2
brew upgrade gphoto2

# Kill PTPCamera (run after each camera connection)
killall PTPCamera

# Test camera
gphoto2 --auto-detect
gphoto2 --summary

# Capture test image
gphoto2 --capture-image-and-download

# List camera settings
gphoto2 --list-config

# Get specific setting
gphoto2 --get-config iso

# Set specific setting
gphoto2 --set-config iso=800

# Build Swift app
swift build

# Run Swift app
swift run

# Clean build
swift package clean
```

---

**Remember**: Always disable WiFi on your camera before connecting USB!

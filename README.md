<p align="center">
  <img src="HOTWIRE.jpg" alt="HOTWIRE" width="600">
</p>

# HOTWIRE - Canon 6D Mark II Tethering App

A native macOS Swift application for tethered shooting with the Canon 6D Mark II camera. Built as a "guitar pedal for cameras" - a live texture engine that sits between the lens and the file.

## Features

### Working ✅
- **Remote Capture**: Trigger shutter remotely with instant image preview
- **Camera Settings**: Control ISO, aperture, and shutter speed from the app
- **Connection Management**: Automatic camera detection and status monitoring
- **Automatic Daemon Killer**: Kills PTPCamera/ptpcamerad on launch - no manual terminal commands needed
- **System Health Panel**: Shows gphoto2 status, daemon status, camera detection, and storage health
- **Image Gallery**: Filmstrip view of captured images with Finder reveal and delete
- **Native Performance**: Built with Swift and SwiftUI for optimal Apple Silicon performance

### In Progress 🚧
- **Live View**: Camera responds but preview not yet displaying in app (gphoto2 capture-preview working)

## Prerequisites

### Hardware Requirements
- Canon 6D Mark II camera
- USB cable (Canon IFC-400PCU or IFC-600PCU recommended)
- Mac with Apple Silicon (M1/M2/M3) or Intel
- macOS 14.0 (Sonoma) or later

### Software Requirements
- Xcode 15.0 or later
- Homebrew package manager
- gphoto2 library

## Installation

### 1. Install Homebrew (if not already installed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install gphoto2

```bash
brew install gphoto2
```

Verify installation:
```bash
gphoto2 --version
```

### 3. Prepare Your Camera

**CRITICAL**: The Canon 6D Mark II's WiFi interferes with USB communication.

1. On your camera, go to **Menu** → **Wireless settings**
2. **Disable WiFi completely**
3. Set camera to **Manual mode** (M) or semi-manual (P/Av/Tv)
4. Connect USB cable to camera and Mac

### 4. Camera Daemons (Automatic)

HOTWIRE now **automatically kills PTPCamera and ptpcamerad** on launch. The app performs aggressive daemon killing during startup and runs a continuous background "Daemon Killer" to prevent macOS from stealing the USB connection.

**No manual steps required!** Just launch the app and it handles everything.

If you need to manually kill daemons (rare):

```bash
killall PTPCamera ptpcamerad
```

### 5. Test Camera Connection

```bash
# Detect camera
gphoto2 --auto-detect

# Get camera summary
gphoto2 --summary

# Test capture
gphoto2 --capture-image-and-download
```

## Building the Application

### Option 1: Using Xcode

1. Open the project directory in Terminal:
   ```bash
   cd /Users/coltonbatts/Desktop/test
   ```

2. Generate Xcode project:
   ```bash
   swift package generate-xcodeproj
   ```

3. Open in Xcode:
   ```bash
   open CanonCameraController.xcodeproj
   ```

4. Select your Mac as the target and click Run (⌘R)

### Option 2: Using Swift Package Manager

Build and run directly from terminal:

```bash
swift build
swift run
```

## Usage

### First Launch

1. Launch the application
2. Grant USB device access when prompted
3. Click "Scan for Camera"
4. If connection fails, verify:
   - WiFi is disabled on camera
   - USB cable is connected
   - Camera is powered on
   - PTPCamera process is killed

### Taking Photos

1. Click "Start Live View" to see real-time preview
2. Adjust camera settings (ISO, Aperture, Shutter) using the dropdowns
3. Click "Capture" to take a photo
4. Images are saved to the current directory

### Troubleshooting Connection Issues

If the camera isn't detected:

```bash
# Kill PTPCamera daemon
killall PTPCamera

# Check if camera is visible via USB
system_profiler SPUSBDataType | grep -A 10 Canon

# Test with gphoto2 directly
gphoto2 --auto-detect

# List available settings
gphoto2 --list-config
```

## Common Issues

### "Camera Not Detected"
- **WiFi enabled on camera**: Disable it completely
- **PTPCamera claiming device**: Run `killall PTPCamera`
- **Wrong USB port**: Try different Thunderbolt/USB ports
- **Cable issue**: Use official Canon cable if possible

### "Device Busy" Error
- Camera's buffer is full (limit ~21 RAW images)
- Download/delete images from camera
- Wait a few seconds and retry

### "Permission Denied" on macOS 14.1+
- Some operations require sudo with gphoto2
- Grant Full Disk Access to Terminal in System Settings → Privacy & Security

### Live View Not Working
- Enable live view mode on camera
- Disable "Continuous AF" in camera settings
- Try restarting the application

## Development Notes

### Architecture
- **ContentView.swift**: Main UI with SwiftUI
- **CameraController.swift**: Camera communication logic
- **gphoto2**: Backend for USB/PTP communication

### gphoto2 Commands Used
```bash
# Camera detection
gphoto2 --auto-detect

# Get camera info
gphoto2 --summary

# Capture image
gphoto2 --capture-image-and-download --filename=IMG.jpg

# Live view preview
gphoto2 --set-config viewfinder=1 --capture-preview --filename=preview.jpg

# Change settings
gphoto2 --set-config iso=800
gphoto2 --set-config aperture=5.6
gphoto2 --set-config shutterspeed=1/125
```

### Future Enhancements
- [ ] Canon EDSDK integration for more features
- [ ] Histogram display overlay
- [ ] Battery and storage monitoring
- [ ] Manual focus controls
- [ ] Intervalometer/timelapse
- [ ] Multi-camera support
- [ ] Export presets and profiles

## License

This is a personal test project. For production use with EDSDK, you must:
1. Register with Canon Developer Programme
2. Comply with Canon's SDK license terms
3. Use gphoto2 only for open-source projects

## Resources

- [Canon Developer Programme](https://developers.canon.com/)
- [gphoto2 Documentation](http://gphoto.org/)
- [libgphoto2 GitHub](https://github.com/gphoto/libgphoto2)
- [Canon 6D Mark II Manual](https://www.canon.com/support)

## Support

This is a test project for personal use. For issues:
1. Check camera WiFi is disabled
2. Verify gphoto2 works in terminal
3. Review troubleshooting section above
4. Check camera is in Manual mode

---

Built with Swift and SwiftUI for macOS. Tested on M2 Mac with Canon 6D Mark II.

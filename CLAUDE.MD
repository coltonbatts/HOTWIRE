# Canon 6D Mark II Camera Control Software - macOS

## Project Overview
Custom camera control application for Canon 6D Mark II on macOS M2. This project provides tethered shooting, live view, remote control, and advanced camera settings management.

## Target Hardware
- **Camera**: Canon 6D Mark II
- **Development Platform**: macOS M2 (Apple Silicon)
- **Connection**: USB (WiFi must be disabled on camera)
- **macOS Version**: 14.1+ (Sonoma and later)

## Technical Approach

### SDK Options
1. **Canon EDSDK** (Primary consideration)
   - Most comprehensive feature set
   - Requires Canon Developer Programme registration (2-4 week approval)
   - Runs via Rosetta 2 on Apple Silicon
   - Restrictive license (incompatible with open-source distribution)
   - Full access to all 6D Mark II features

2. **gphoto2/libgphoto2** (Open-source alternative)
   - LGPL licensed - fully open-source compatible
   - Native Apple Silicon support via Homebrew
   - 90% feature parity with EDSDK for typical workflows
   - Install: `brew install gphoto2`
   - Requires `sudo` on macOS 14.1+
   - Must kill PTPCamera process: `killall PTPCamera`

### Framework Options
- **Swift/SwiftUI**: Native macOS, best performance, ~10MB bundle
- **Tauri + Rust**: Modern, 2-10MB bundle, 50-60% less memory than Electron
- **Electron + Node.js**: Familiar web stack, ~85MB bundle, rapid development
- **Python + PyQt**: Rapid prototyping, complex distribution

## Critical Hardware Requirements

### MUST DISABLE WIFI
The Canon 6D Mark II has WiFi interference with USB communication. **Always disable WiFi on camera before USB connection** or experience:
- Connection failures
- "Device busy" errors
- Button freezing
- Intermittent dropouts

### USB Cable Requirements
- Use Canon IFC-400PCU (Mini-B) or IFC-600PCU (Micro-B)
- Avoid extension cables (reliability issues)
- Direct connection to Mac Thunderbolt ports preferred

### macOS Permissions Required
- USB device access (`com.apple.security.device.usb`)
- Must kill PTPCamera daemon before connecting
- Requires code signing and notarization for distribution
- User approval in System Settings → Privacy & Security

## Camera Capabilities
- **Live View**: 1920×1080/30fps, ~100-200ms latency
- **Burst Mode**: 6.5fps
- **ISO Range**: 100-40000
- **Shutter Speed**: 1/4000-30s plus bulb
- **White Balance**: Color temp 2500-10000K
- **Focus**: 45-point AF, manual stepping in live view only
- **File Transfer**: USB 2.0/3.0, ~2-5s for RAW files
- **Buffer**: ~21 RAW frames before "device busy"

## Implementation Roadmap

### Phase 1: Validation (Week 1)
- [ ] Register for Canon Developer Programme
- [ ] Install gphoto2 and test basic connectivity
- [ ] Verify camera detection and communication
- [ ] Test live view streaming
- [ ] Validate settings control

### Phase 2: Architecture Setup (Week 2)
- [ ] Choose framework (Swift/Tauri/Electron)
- [ ] Set up development environment
- [ ] Configure code signing certificates
- [ ] Create minimal project skeleton
- [ ] Implement USB device notifications

### Phase 3: Core Features (Weeks 3-6)
- [ ] Camera connection management
- [ ] Live view display (5fps minimum)
- [ ] Remote shutter control (single/continuous/bulb)
- [ ] Settings UI (ISO/aperture/shutter/WB)
- [ ] File transfer with progress
- [ ] Event polling and state sync
- [ ] WiFi detection warnings

### Phase 4: Advanced Features (Weeks 7-9)
- [ ] Manual focus control (step buttons)
- [ ] Histogram overlay
- [ ] Battery and storage monitoring
- [ ] Multi-camera support
- [ ] Intervalometer functionality
- [ ] Capture-to-RAM mode

### Phase 5: Polish (Weeks 10-12)
- [ ] macOS permission handling
- [ ] Comprehensive error handling
- [ ] Performance optimization
- [ ] Keyboard shortcuts
- [ ] Preferences persistence
- [ ] Code signing and notarization
- [ ] Testing on clean macOS install

## Technical Limitations

### Camera Restrictions
- Manual focus only works in live view with "Continuous AF" disabled
- Only relative focus steps (near/far), not absolute positioning
- Remote capture requires Manual or semi-manual modes (P/Av/Tv)
- No CCAPI support (WiFi REST API only on R-series cameras)

### macOS Challenges
- PTPCamera daemon auto-claims USB cameras
- macOS 14.1+ requires sudo for some USB operations
- macOS 15 Sequoia added new permission requirements
- Gatekeeper prevents unsigned apps from launching

### Legal Constraints
- EDSDK license prohibits reverse engineering
- Cannot combine EDSDK with open-source licenses
- Distribution restrictions outside Europe
- Must use gphoto2 for true open-source projects

## Development Commands

### gphoto2 Testing
```bash
# Detect camera
gphoto2 --auto-detect

# Camera summary
gphoto2 --summary

# Capture image
gphoto2 --capture-image-and-download

# Enable live view
gphoto2 --set-config viewfinder=1 --capture-movie

# List settings
gphoto2 --list-config

# Change ISO
gphoto2 --set-config iso=800

# Kill PTPCamera process
killall PTPCamera
```

### Python Setup
```bash
pip3 install gphoto2
```

## Resources
- Canon Developer Programme: https://developers.canon.com/
- gphoto2 documentation: http://gphoto.org/
- libgphoto2 GitHub: https://github.com/gphoto/libgphoto2
- PTP Protocol: ISO 15740:2013
- Julian Schroden's PTP/IP series: Exploring the PTP/IP Protocol

## Project Status

### Current Implementation
- **Framework**: Swift/SwiftUI (native macOS)
- **SDK**: gphoto2/libgphoto2 (open-source)
- **Use Case**: Personal testing and development

### Completed
- ✅ Project structure created
- ✅ Swift Package Manager setup
- ✅ Main UI with connection status
- ✅ Camera controller with gphoto2 integration
- ✅ Live view implementation
- ✅ Remote capture functionality
- ✅ Settings control (ISO, aperture, shutter)
- ✅ Setup script and documentation

### Next Steps
1. Run `./setup.sh` to install dependencies
2. Connect Canon 6D Mark II via USB (WiFi disabled!)
3. Build and test the application
4. Iterate on features based on testing

### File Structure
```
/Users/coltonbatts/Desktop/test/
├── CLAUDE.MD                           # This file - project context
├── README.md                           # User-facing documentation
├── Package.swift                       # Swift Package Manager config
├── setup.sh                            # Automated setup script
├── .gitignore                          # Git ignore rules
└── Sources/
    └── CanonCameraController/
        ├── main.swift                  # App entry point
        ├── ContentView.swift           # Main UI
        └── CameraController.swift      # Camera logic
```

## Notes for Claude
- This directory is not currently a git repository
- Target platform: macOS M2 (Apple Silicon)
- Development with AI coding tools (Claude/Cursor)
- 8-12 week estimated timeline with AI assistance
- **Decision made**: gphoto2 (open-source) + Swift/SwiftUI for personal use

## Last Updated
2025-11-24

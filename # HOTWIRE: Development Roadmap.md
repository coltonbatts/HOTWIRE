# HOTWIRE: Development Roadmap

> **Concept:** A "Guitar Pedal for Cameras."
> HOTWIRE is a live texture engine that sits between the lens and the file. It allows photographers to apply "heavy, gothy, vibe" effects (dithering, threshold, overlays) to the live view stream and capture baked-in JPEGs in real-time.

## Phase 1: The Chassis (Core Stability)
*Focus: Rock-solid connection and basic functionality.*
- [x] **USB Connection:** Establish communication via `gphoto2`.
- [x] **Live View:** Get the raw stream displaying in the window.
- [ ] **Daemon Killer:** Automate the killing of `PTPCamera` on launch so the user never sees a connection error.
- [ ] **Manual Controls:** Ensure ISO, Aperture, and Shutter Speed toggles are responsive and accurate.

## Phase 2: The Stompbox (Basic Effects)
*Focus: The first set of "Pedals" in the signal chain.*
- [ ] **The "Xerox" Effect:**
    - Implement a Core Image pipeline (`CIFilter`) on the live stream.
    - Create a "High Contrast / Threshold" mode (Pure Black & White).
- [ ] **The "Grain" Pedal:**
    - Add a procedural noise overlay to simulate high-ISO film grain.
- [ ] **The "Tint" Pedal:**
    - Simple color mapping (e.g., "Night Vision Green" or "Red Room").

## Phase 3: The Rack (Advanced Processing)
*Focus: Complex, aesthetic-defining features.*
- [ ] **Dithering Engine:**
    - Implement Floyd-Steinberg or Atkinson dithering (likely using Metal Shaders) for that retro/bit-crushed look.
- [ ] **Texture Overlays:**
    - Allow users to drag-and-drop a PNG (e.g., a band logo, a grunge border, or a HUD interface) that sits on top of the image.
    - "Bake" this overlay into the final captured JPEG.
- [ ] **Aspect Ratio Masking:**
    - Visual overlays for 1:1 (Square), 4:5 (IG), or 16:9 (Cinema) cropping.

## Phase 4: The Studio (Workflow)
- [ ] **Preset Saving:** Save a combination of Camera Settings + Effects as a "Patch" (e.g., "Gothic High-Contrast" or "Soft Dreamy").
- [ ] **Direct-to-Disk:** Ensure captured images (with effects applied) save instantly to a watched folder for immediate review.

## Backlog / "Blue Sky" Ideas
- [ ] MIDI Control support (use a physical MIDI controller to adjust contrast/grain).
- [ ] Audio Reactive (glitch effects that react to microphone input/music).
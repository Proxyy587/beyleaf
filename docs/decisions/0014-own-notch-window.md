# 0014: Our own notch window instead of DynamicNotchKit

- **Status:** accepted (2026-11-24). **Supersedes 0007.**
- **Context:**
  - Building DynamicNotchKit @ `cd0b3e52` with the Command Line Tools fails. It uses SwiftUI's `@Entry` macro, and "plugin for module 'SwiftUIMacros' not found": that macro plugin ships only with full Xcode.
  - Belay's differentiator is the notch's motion and feel (`docs/features.md` §1, §7), so owning the window, shape and springs is valuable anyway.
- **Decision:**
  - Belay draws its own notch:
    - a borderless, non-activating `NSPanel` above the menu bar (it never becomes key, and passes clicks through while closed);
    - a `NotchShape` with animatable ear and bottom radii, springing between the hardware-notch size and the open size;
    - a floating rounded island on screens without a notch.
  - Geometry uses `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`, the approach in Perch's `NotchGeometry` (MIT). Hover uses Perch's cursor-polling cadence.
  - DynamicNotchKit becomes **reference only**. No code is copied from it. Its shape idea (concave top corners, rounded bottom) is common to notch apps and was re-implemented.
- **Consequences:**
  - No SwiftPM dependencies in the app.
  - We maintain the notch window ourselves, including multi-display and camera-island cases.
  - Test on notch, no-notch and external-display setups.

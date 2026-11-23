# 0001: Swift shell + TypeScript core

- **Status:** accepted (2026-11-24)
- **Context:** The notch, haptics, global hotkeys, on-device speech and Accessibility are native-only on macOS. The developer is strongest in TypeScript. The most reusable upstream code is Swift (Perch, Clicky, Avo) and TypeScript (OpenMausBot).
- **Decision:** `Belay.app` (Swift 6 / SwiftUI / AppKit) renders, listens and touches macOS. `belayd` (TypeScript on Bun, compiled to one binary bundled in the app) owns all product logic. They talk only through the protocol in `docs/architecture.md` §4.
- **Consequences:** Two languages and two processes. Logic is testable headless. The core can be replaced (0002) without touching the shell.

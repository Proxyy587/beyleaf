# 0013: Build the Mac shell with SwiftPM and a bundle script (not XcodeGen)

- **Status:** accepted (2026-11-24). Replaces the XcodeGen plan in `docs/tech-stack.md` and `apps/mac/README.md`.
- **Context:**
  - The dev Mac has only the Command Line Tools (Swift 6.2.3); Xcode and XcodeGen are not installed.
  - Perch (MIT, `refs.lock`) ships a notch app built with SwiftPM, wrapping the binary into an `.app` with a short script. The script uses `vtool` to record the real SDK version so macOS 26 applies the current look, plus PlistBuddy and `codesign`.
- **Decision:**
  - `apps/mac` is a SwiftPM package (`Package.swift`, `Sources/Belay`).
  - `apps/mac/scripts/run.sh` builds, bundles (`Resources/Info.plist`, LSUIElement), stamps the SDK version, signs (ad hoc for now) and launches. This is adapted from Perch's `scripts/run.sh` with a provenance note.
- **Consequences:**
  - The app builds without Xcode.
  - Ad-hoc signatures change every build, so macOS may re-ask for Automation permission after each rebuild. A stable local signing identity, and Developer ID plus notarization for releases, come later.
  - If we later need Xcode-only features (asset catalogs, App Intents metadata, previews), revisit with a new ADR.

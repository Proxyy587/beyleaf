# 0007: DynamicNotchKit as a pinned SwiftPM dependency

- **Status:** accepted (2026-11-24)
- **Context:** DynamicNotchKit (MIT) provides the notch and notchless floating window. It is a maintained Swift package.
- **Decision:** Depend on it through SwiftPM, pinned to commit `cd0b3e52d537db115ad3a9d89601f20e0bee8d27` (or the release tag containing it), instead of vendoring the source.
- **Consequences:** Upgrades are a one-line, reviewable bump. If we need to patch it, fork it under the Belay org and pin the fork. Never copy its files into the app.

# 0017: Music bars follow the real audio through a Core Audio process tap

- **Status:** accepted (2026-11-24)
- **Context:** The closed notch showed a looping sine "equalizer" while music played: a decorative loop that didn't
  match the music (docs/design.md §2, user feedback). Real bars need the audio itself. Options:
  - Core Audio process taps (`CATapDescription`, `AudioHardwareCreateProcessTap`, macOS 14.2+; verified in the
    CLT SDK 26.2 headers `CoreAudio/AudioHardwareTapping.h` and `CATapDescription.h`);
  - ScreenCaptureKit audio (needs Screen Recording permission and a capture stream: heavier, scarier prompt);
  - a virtual audio driver (installs system software; out of scope);
  - fake animation (rejected: "only real things").
- **Decision:**
  - Tap **only the player's processes** (Music or Spotify, matched by bundle-ID prefix via
    `kAudioHardwarePropertyProcessObjectList` / `kAudioProcessPropertyBundleID`), as a private, unmuted stereo
    mixdown tap, read through a private aggregate device and an IOProc (`apps/mac/Sources/Belay/Audio/MusicBeat.swift`).
  - Analyse in memory with Accelerate (`BeatAnalyzer.swift`): 1024-point FFT, 4 log-spaced bands, automatic gain,
    fast attack / slow release, kick-band energy onsets that add a small scale pulse. Nothing is recorded, written
    or sent.
  - Capture runs only while music plays **and** the music wing is on screen (closed notch, screens awake), with the
    bars setting on and motion allowed. Every other state destroys the tap and the aggregate device.
  - `NSAudioCaptureUsageDescription` explains the prompt. If capture fails, delivers no buffers, or only digital
    silence for 3 s, the wing shows a static glyph until the next track. Reduced motion → static glyph, no capture.
  - Bars are ink, not live green (green is for status text and dots, design.md §3).
- **Consequences:**
  - macOS 14.0–14.1 get the static glyph (the app still targets 14.0).
  - A first play asks for audio-capture permission once; ad-hoc-signed dev builds may ask again after rebuilds.
  - `apps/mac/scripts/beat-selftest.sh` checks the analyser on synthetic signals (silence, sine, kick, cost).
  - **UNVERIFIED:** live on-device behaviour (bars moving with real music, Spotify's audio coming from a helper
    process, the exact denied-permission behaviour). The start/stop path and the no-buffer fallback are verified
    by logs with a paused player.

# apps/mac: Belay.app (Swift shell)

Renders, listens and touches macOS; **no product logic** (ADR 0001). A SwiftPM package (ADR 0013), with no Xcode needed.

```sh
apps/mac/scripts/run.sh            # build, bundle, ad-hoc sign, launch (menu bar climber icon → Quit)
apps/mac/scripts/run.sh --expand   # launch with the notch open (testing, screenshots)
apps/mac/scripts/run.sh --settings # launch and open Settings
CONFIG=release apps/mac/scripts/run.sh --build-only
```

**Status: v0.0 prototype**, designed to `docs/design.md` (tokens in `Sources/Belay/Design/Tokens.swift`).
- Our own notch window (ADR 0014) springs open on hover, with a configurable hover delay.
- **Closed notch** fits the hardware exactly. Wings appear only for live activities: music (artwork and real-audio beat bars), screenshot copied, low battery, internet lost or back.
- **Open panel:** the Settings gear, the now-playing hero (Music/Spotify, with controls) or one "Not playing" line, and the last copied screenshot. What's shown and why: `docs/ui-inventory.md`.
- **Screenshot auto-copy** (N1): a Spotlight query on `kMDItemIsScreenCapture` copies every new screenshot (PNG + TIFF + file URL), wherever it's saved.
- **Settings** (O1): General, Layout, Screenshots, AI accounts (detects the `claude`/`codex` CLIs and versions; never credentials), About; Theme, Typography, Colours, Surface and Motion behind "Show advanced settings".
- Idle CPU measured at 0.0–0.2% (budget < 1%).
- No agent features yet.

| Folder (planned) | Responsibility | Feature IDs | Adapt from |
|---|---|---|---|
| `Belay/App/` | App entry, `Supervisor` (launch/restart `belayd`), Settings | — | — |
| `Sources/Belay/Design/` | `Tokens.swift` (colour, type, shape, space, motion, haptics) + `StatusLine` | all UI | `docs/design.md` |
| `Sources/Belay/Settings/` | `AppSettings` (persisted prefs), `SettingsWindow` | O1–O3, N3 | — |
| `Sources/Belay/Notch/` | `NotchPanel`, `NotchShape`, `NotchRoot`, `NotchController` (hover polling, open/close), views | A1, B8, E3 | `third_party/perch/Sources/PerchCore/NotchGeometry.swift`, `NotchMachine.swift` |
| `Belay/Cards/` | RopeCard, QuestCard, Logbook views | A2, F*, G* | — |
| `Belay/Character/` | Sprite atlas + state machine | A1, A3 | — |
| `Belay/Feel/` | Haptics, sounds, springs | E1, E2, E3 | — |
| `Belay/Voice/` | Hold-to-talk, on-device STT, TTS, waveform | C1, C2, A4 | `third_party/clicky/…/GlobalPushToTalkShortcutMonitor.swift`, `AppleSpeechTranscriptionProvider.swift`, `BuddyTranscriptionProvider.swift`; `third_party/avo/Avo/Notch/DictationWave.swift` |
| `Belay/MacBridge/` | NowPlaying, WindowLocator, Overlay, Mac actions | B1, A7, A8, J3 | `third_party/avo/Avo/Tools/SpotifyTools.swift`; `third_party/perch/Sources/Perch/Terminals.swift`; `third_party/clicky/…/OverlayWindow.swift` |
| `Belay/Protocol/` | `Generated.swift` (from `core/packages/protocol`, never hand-edited) + CoreClient | — | — |

No package dependencies (ADR 0014). Minimum macOS 14 (`docs/tech-stack.md` §3). Built paths so far: `Sources/Belay/{App,Notch,MacBridge,Design,Settings}`; the remaining folders above are planned.

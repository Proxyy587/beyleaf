# apps/mac: Belay.app (Swift shell)

Renders, listens and touches macOS; **no product logic** (ADR 0001). A SwiftPM package (ADR 0013), with no Xcode needed.

```sh
apps/mac/scripts/run.sh            # build, bundle, ad-hoc sign, launch (menu bar climber icon → Quit)
apps/mac/scripts/run.sh --expand   # launch with the notch open (testing, screenshots)
CONFIG=release apps/mac/scripts/run.sh --build-only
```

**Status: v0.0 prototype.**
- Our own notch window (ADR 0014) springs open on hover. Compact wings show the climber and battery, or equalizer bars while music plays.
- The open panel has: clock/date; now playing for Music and Spotify with play/pause/skip; Wi-Fi; battery; a volume slider; and a placeholder drop zone for Convert.
- Idle CPU measured at 0.0% (budget < 1%).
- No agent features yet.

| Folder (planned) | Responsibility | Feature IDs | Adapt from |
|---|---|---|---|
| `Belay/App/` | App entry, `Supervisor` (launch/restart `belayd`), Settings | — | — |
| `Sources/Belay/Notch/` | `NotchPanel`, `NotchShape`, `NotchRoot`, `NotchController` (hover polling, open/close), views | A1, B8, E3 | `third_party/perch/Sources/PerchCore/NotchGeometry.swift`, `NotchMachine.swift` |
| `Belay/Cards/` | RopeCard, QuestCard, Logbook views | A2, F*, G* | — |
| `Belay/Character/` | Sprite atlas + state machine | A1, A3 | — |
| `Belay/Feel/` | Haptics, sounds, springs | E1, E2, E3 | — |
| `Belay/Voice/` | Hold-to-talk, on-device STT, TTS, waveform | C1, C2, A4 | `third_party/clicky/…/GlobalPushToTalkShortcutMonitor.swift`, `AppleSpeechTranscriptionProvider.swift`, `BuddyTranscriptionProvider.swift`; `third_party/avo/Avo/Notch/DictationWave.swift` |
| `Belay/MacBridge/` | NowPlaying, WindowLocator, Overlay, Mac actions | B1, A7, A8, J3 | `third_party/avo/Avo/Tools/SpotifyTools.swift`; `third_party/perch/Sources/Perch/Terminals.swift`; `third_party/clicky/…/OverlayWindow.swift` |
| `Belay/Protocol/` | `Generated.swift` (from `core/packages/protocol`, never hand-edited) + CoreClient | — | — |

No package dependencies (ADR 0014). Minimum macOS 14 (`docs/tech-stack.md` §3). Built paths so far: `Sources/Belay/{App,Notch,MacBridge,Feel}`; the remaining folders above are planned.

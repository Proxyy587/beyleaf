# apps/mac: Belay.app (Swift shell)

Renders, listens and touches macOS; **no product logic** (ADR 0001). Generated from `project.yml` with XcodeGen.
The `.xcodeproj` is git-ignored.

| Folder (planned) | Responsibility | Feature IDs | Adapt from |
|---|---|---|---|
| `Belay/App/` | App entry, `Supervisor` (launch/restart `belayd`), Settings | — | — |
| `Belay/Notch/` | Island + base camp on DynamicNotchKit; notch geometry; open/close state | A1, B8, E3 | `third_party/perch/Sources/PerchCore/NotchGeometry.swift`, `NotchMachine.swift` |
| `Belay/Cards/` | RopeCard, QuestCard, Logbook views | A2, F*, G* | — |
| `Belay/Character/` | Sprite atlas + state machine | A1, A3 | — |
| `Belay/Feel/` | Haptics, sounds, springs | E1, E2, E3 | — |
| `Belay/Voice/` | Hold-to-talk, on-device STT, TTS, waveform | C1, C2, A4 | `third_party/clicky/…/GlobalPushToTalkShortcutMonitor.swift`, `AppleSpeechTranscriptionProvider.swift`, `BuddyTranscriptionProvider.swift`; `third_party/avo/Avo/Notch/DictationWave.swift` |
| `Belay/MacBridge/` | NowPlaying, WindowLocator, Overlay, Mac actions | B1, A7, A8, J3 | `third_party/avo/Avo/Tools/SpotifyTools.swift`; `third_party/perch/Sources/Perch/Terminals.swift`; `third_party/clicky/…/OverlayWindow.swift` |
| `Belay/Protocol/` | `Generated.swift` (from `core/packages/protocol`, never hand-edited) + CoreClient | — | — |

Dependency: DynamicNotchKit via SwiftPM, pinned (ADR 0007). Minimum macOS 14 (`docs/tech-stack.md` §3).

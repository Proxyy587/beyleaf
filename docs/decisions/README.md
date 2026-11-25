# Architecture decision records

One file per decision that is expensive to reverse. Status is one of `accepted`, `superseded by NNNN`, or `proposed`.
New decision: copy the newest file, bump the number, and link it here.

| # | Decision | Status |
|---|---|---|
| [0001](0001-swift-shell-ts-core.md) | Swift shell + TypeScript core, talking over a versioned local protocol | accepted |
| [0002](0002-rust-core-later.md) | Rust core deferred to v0.3, behind the same protocol | accepted |
| [0003](0003-no-gpl-code.md) | No GPL code; MIT/Apache-2.0 only, vendored with provenance | accepted |
| [0004](0004-engines-not-logins.md) | Use AI subscriptions only through the user's own CLIs | accepted |
| [0005](0005-fail-open.md) | Fail open to the agent's own prompt; never auto-allow | accepted |
| [0006](0006-unix-socket-hook-transport.md) | Hooks reach the core over a Unix socket via a command-hook shim | accepted |
| [0007](0007-dynamicnotchkit-dependency.md) | DynamicNotchKit as a pinned SwiftPM dependency, not vendored | superseded by 0014 |
| [0008](0008-source-available-inspiration-only.md) | Source-available projects (e.g. dusk bot) are product inspiration only: not cloned, not read for code | accepted |
| [0009](0009-crew-hub-and-tool-surface.md) | Crew is hub-and-spoke through CrewService; one ToolHost exposed to CLI engines via a capability-scoped MCP proxy | accepted |
| [0010](0010-runtimes-and-turns.md) | Members think through pluggable runtimes, in bounded turns | accepted |
| [0011](0011-untrusted-content-cannot-grant-permission.md) | Untrusted content can't grant permission (taint tracking) | accepted |
| [0012](0012-converters-builtin-first.md) | Converters: macOS built-ins first, ship only permissive code, detect GPL-family tools | accepted |
| [0013](0013-swiftpm-app-bundle.md) | Build the Mac shell with SwiftPM + a bundle script, not XcodeGen | accepted |
| [0014](0014-own-notch-window.md) | Our own notch window instead of DynamicNotchKit (supersedes 0007) | accepted |
| [0015](0015-user-themes.md) | Every visual token comes from a user theme (fonts, colours, surface, shape, layout, motion) | accepted |
| [0016](0016-trading-non-custodial.md) | Trading agent is non-custodial; the LLM never places orders | accepted for design |
| [0017](0017-music-beat-process-tap.md) | Music bars follow the player's real audio through a Core Audio process tap | accepted |
| [0018](0018-duskbot-local-study-clone.md) | dusk bot may be cloned locally for design study, never copied (amends 0008) | accepted |
| [0019](0019-notch-widgets.md) | The open notch is user-ordered widgets, packed with no gaps (moves row order out of the theme, 0015) | accepted |
| [0020](0020-steer-is-the-users-words.md) | A steer is the user's own words, attributed and verbatim (from spike A0) | accepted |
| [0021](0021-notch-pages.md) | The open notch is pages of packed widgets; `AppSettings.pages` replaces `widgets` (extends 0019) | accepted |
| [0022](0022-jarvis-direction.md) | Buddies, routines, connectors and Mac control are one direction; crew = buddies | proposed |

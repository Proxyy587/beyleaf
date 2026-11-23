# Belay: tech stack

**Decided:** 2026-11-24.

**Inputs:** `features-final.md` (what we build), `oss-reuse.md` (what we borrow), `feasibility.md` (what the agents expose).

**Constraints:**
- One developer, strong in TypeScript, Node and Python; new to Swift and Rust.
- v0.1 ships in 2 weeks.
- Free, MIT, no servers, Mac first, with other platforms later.

---

## 1. The decision in one table

| Layer | Choice | Why |
|---|---|---|
| **Mac app (shell)** | **Swift 6 + SwiftUI, with AppKit where needed** (`NSPanel`, `NSEvent`, `NSHapticFeedbackManager`, Accessibility API) | The notch, haptics, global hotkeys, on-device speech and Accessibility are native-only. This is the polish we compete on (`feasibility.md` §4). |
| Notch window | **DynamicNotchKit** (MIT) | Notch and floating-island windows already solved (`oss-reuse.md` §4) |
| Project generation | **XcodeGen** (`project.yml`) | No hand-edited `.xcodeproj` merge pain; Avo uses the same |
| Auto-update | **Sparkle** | The de facto standard for signed Mac updates outside the App Store |
| **Core (`belayd`)** | **TypeScript on Bun**, shipped as a **single compiled binary** (`bun build --compile`) inside the `.app` | Your strongest language. MausBot's engine layer (Apache-2.0) is TypeScript. Fastest path to the 2-week ship. |
| Core HTTP/WS server | **Hono** on `Bun.serve` (HTTP hooks + WebSocket to the shell) | Small, typed, fast. No framework weight. |
| Core storage | **SQLite via `bun:sqlite`** (built into Bun) | Sessions, approvals, logbook, quests. One file, zero setup. |
| Schemas / protocol | **zod** in TS. Swift `Codable` types **generated** from the schemas (zod → JSON Schema → quicktype) | One source of truth across the language boundary |
| Rule packs | **YAML + a typed rule DSL**, validated by zod | Community-editable without code (I2) |
| Share cards | **satori** (JSX → SVG) + **@resvg/resvg-js** (SVG → PNG) | Pure TS, no browser, no server |
| Tests | **bun test** (core); **XCTest / Swift Testing** (shell); a live **agent e2e harness** (A6) | |
| **CLI (`belay`)** | The same `belayd` binary with subcommands (`belay status`, `belay hook codex …`, `belay log`) | One artifact to sign and ship |
| **Website + docs** | **Next.js on Vercel**, MDX docs | Your strength; free hosting |
| CI/CD | **GitHub Actions** on macOS runners: build, test, sign, **notarize**, DMG, Sparkle appcast, GitHub Release | Free for public repos |
| Licence | **MIT**. Third-party code kept under its own MIT/Apache-2.0 terms in `THIRD_PARTY_NOTICES.md`. **No GPL code.** | `oss-reuse.md` §6 |

## 2. The Rust question, answered

You asked whether Rust would bring better performance and help reach all devices. Here is the call.

**Not for v0.1. Yes as the cross-platform core in v0.3, behind the same protocol.**

| | TS/Bun core (v0.1) | Rust core (v0.3+) |
|---|---|---|
| Ship in 2 weeks | ✅ Your language, MausBot code reusable | ❌ New language, nothing to reuse |
| Performance needed | The core mostly *waits*: hooks, a few events per second, regex rules. It is I/O-bound, so Bun is fast enough. | Overkill now; matters on low-end Windows/Linux devices and for battery |
| Binary size / memory | Bigger (a Bun runtime is embedded). Exact size **UNVERIFIED**; measure on Day 1. | Small, low memory |
| Cross-platform | Bun runs on Mac, Windows and Linux, so it already works there | Best story: one core + **Tauri** shells on Windows/Linux |
| Plugins (I1) | Natural: plugins are TS modules | Needs an embedded JS runtime for TS plugins (e.g. `deno_core`) or WASM plugins |

**Why this isn't a dead end:**
- The Swift shell never talks to TypeScript directly. It talks to a **versioned local protocol** (`architecture.md` §4).
- Porting the core to Rust later is rewriting one process against a fixed contract and test suite, not rewriting the app.
- The hot paths (hook gateway, approval broker, risk engine) are small and well-specified, which is the easy part to port.

**Trigger to start the Rust port:**
- Either the Windows/Linux build is greenlit,
- or measured idle memory or CPU of `belayd` breaks the budget (§4).

The idle budget (<1% CPU, `features.md` E8) applies to **both processes together**.

## 3. Minimum platform targets

| Target | Version | Reason |
|---|---|---|
| macOS | **14 Sonoma+** (Apple Silicon and Intel) | Broad reach |
| Enhanced on macOS | **26+** | Newer speech APIs (SpeechAnalyzer) and Apple's on-device Foundation Models where available. Both **UNVERIFIED on our hardware**; feature-flag them. |
| Hardware | Notch, camera-island and no-notch Macs; external displays | B8 |
| Agents | Claude Code (current; the hook features used are documented at the v2.1.2xx–3xx level), Codex (current) | `feasibility.md` |
| Bun | Current stable at project start; pin it in `.bun-version` | Reproducible builds |
| Xcode | Current stable; pin it in CI | |

## 4. Performance budgets (measured in CI from v0.2)

| Metric | Budget |
|---|---|
| Hook received → rope-drop visible | **< 150 ms p95** (perceived instant; product budget < 1 s) |
| Voice release → intent applied | < 1.2 s on-device |
| Idle CPU, both processes | < 1% |
| Idle memory, both processes | < 150 MB (revisit after the Day 1 Bun measurement) |
| Cold launch to notch visible | < 1.5 s |
| DMG size | < 80 MB |

## 5. What we explicitly did not pick, and why

| Rejected | Why |
|---|---|
| **Electron** (MausBot's choice) | Can't do a native-feeling notch, haptics or on-device speech well; heavy |
| **Tauri now** | A notch, haptics and Accessibility still need native Mac code, so it's two hard things instead of one. Good for the v0.3 Windows/Linux shells. |
| **All-Swift** (no sidecar) | All logic in a language you don't know, and MausBot's TypeScript engine code becomes unusable |
| **React Native macOS** | Same native-surface problems; smaller ecosystem for this |
| **Cloud backend** | Breaks "no account, no servers"; costs money |
| **Agent SDK on the user's subscription** | Not permitted by Anthropic (`oss-reuse.md` §2); API-key only |

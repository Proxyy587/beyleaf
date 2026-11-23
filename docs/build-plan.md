# Belay: 2-week build plan

**Written:** 2026-11-24.

**Builder:** one developer. Strong in TypeScript and Node, with no Swift experience, using Claude Code heavily.

**Ship date:** Day 14.

**Scope:** F1–F8 in `product.md` §5. Nothing else.

---

## 1. Architecture

```
┌─────────────── Belay.app (Swift / SwiftUI, forked from Clicky, MIT) ───────────────┐
│  NotchPanel (NSPanel, top-centre)  ·  ApprovalCard  ·  Character sprites + sounds   │
│  PushToTalk (global hotkey) → Apple on-device speech → text                         │
│  TTS (AVSpeechSynthesizer)                                                          │
│                ▲  WebSocket over 0600 Unix socket  (JSON events + commands)          │
└────────────────┼───────────────────────────────────────────────────────────────────┘
                 │
┌────────────────┴──────── belayd (TypeScript → single binary via `bun build --compile`) ──┐
│  HTTP  POST /hook/claude/:event   ← `belay-hook claude <event>` (Unix socket, ADR 0006) │
│  HTTP  POST /hook/codex/:event    ← `belayd hook codex` command shim (stdin → POST)     │
│  Session store (in memory + small JSON on disk) · Pending-approval map (holds response) │
│  Risk rules engine · Voice-intent parser · Status sentence templates                   │
│  Share-card renderer (satori → SVG → PNG)                                              │
│  Installer: writes / removes hook config with a preview diff                           │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

**Why split it this way:**
- **TypeScript holds all the logic you'll iterate on**: rules, parsing, state, cards.
- **Swift holds only what must be native**: notch window, hotkey, microphone, speech, animation.
- **They talk through one small WebSocket protocol.** Each side can be tested alone, and you can drive `belayd` from `curl` before any Swift exists.

## 2. Hook wiring (documented interfaces only)

**Claude Code** (`~/.claude/settings.json`, user scope):

> **Superseded transport (ADR 0006):** hooks are now `command` hooks running the `belay-hook` shim, which `curl --unix-socket`s to `belayd`, instead of `http` hooks on a localhost port. The decision payloads below are unchanged.

- **`PermissionRequest`** is the approval path. A `command` hook runs `belay-hook claude PermissionRequest` with `timeout` up to 3600 s (Perch uses 3600).
  - `belayd` keeps the HTTP request open until you answer.
  - It then returns `{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{…}}}`:
    - Allow: `behavior:"allow"`
    - Always: `behavior:"allow"` plus `updatedPermissions:[{type:"addRules",…}]`
    - Deny with steering: `behavior:"deny", message:"<your words>"`
    - Stop: `behavior:"deny", interrupt:true`
  - If no answer comes before the timeout, it returns **no decision**, so Claude Code falls back to its normal terminal prompt.
- **Status:** `SessionStart`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop`, `SessionEnd`, and `PermissionDenied` (auto-mode blocks), all sent to `/hook/claude/:event`. They return immediately with no decision.
- **Fail-safe:** if `belayd` is down the shim finds no socket and prints nothing (no decision). The normal flow continues, so nothing is auto-allowed.

**Codex** (`~/.codex/hooks.json`):

- A `command` hook runs `belayd hook codex <event>`.
- The shim reads the JSON on stdin, POSTs it to `belayd`, and prints the reply.
- `PermissionRequest` supports **allow, or deny with a `message`, only**. No `updatedInput`, no `interrupt` ("fail closed today"). So with Codex, "Always" and "Stop" are unavailable. The UI greys them out.
- Codex requires the user to **review and trust** non-managed hooks. Onboarding must walk them through it.

**Spike this on Day 1.** If command-hook response holding, Bun on a Unix socket, or Codex's hold time behave differently than expected, find out before building anything on top.

## 3. Day-by-day plan

| Day | Deliverable | Done when |
|---|---|---|
| **1** | **Spikes.** (a) Fork Clicky, build it in Xcode, rename it Belay. (b) Minimal `belayd` in Bun that logs every Claude Code hook. (c) Hold a `PermissionRequest` open for 20 s, then deny with a `message`. | You watch Claude Code accept your denial message and change course. **This is the go/no-go.** |
| **2** | `belayd` session store and state machine (working, waiting, done, error) for Claude Code. WebSocket protocol v0. Codex shim and Codex `PermissionRequest`. | `wscat` shows clean live state for 2 Claude sessions and 1 Codex session |
| **3** | Swift: notch panel on DynamicNotchKit (MIT; see `oss-reuse.md` §4): collapsed pill with session dots, hover to expand into a list. No-notch fallback. Strip Clicky's cloud voice and Cloudflare code. | Dots change colour live as agents work |
| **4** | Approval card with Allow, Deny, Always and keyboard shortcuts. Full round trip to the held hook. Timeout falls back to the terminal. | You approve a real Claude Code command from the notch in under 1 s |
| **5** | Risk rules engine in TypeScript (table-driven regexes and path checks, with unit tests) and the "catch" event | 20+ test cases pass; `rm -rf ./data` triggers a catch |
| **6** | Voice: hold-to-talk hotkey, Apple on-device speech recognition, a TS intent parser (`yes`, `no`, `always`, `stop`, `no … instead …` becomes a deny message), and TTS reading the request | The full hero flow works end to end, ugly but working |
| **7** | **Buffer and dogfood.** Use it all day on real work. Record a rough clip and post it on X as build-in-public #1. | A rough clip is posted |
| **8** | Status Q&A ("what are my agents doing?") from templates. Voice lines (about 30). Sound effects. Mute while the asking terminal is focused. | You get a spoken status of 3 sessions |
| **9** | Character: 5 states × about 4 frames of pixel art, plus the catch and slide-down animation and summit flag | It looks good enough that you'd screenshot it |
| **10** | Daily log card: stats in `belayd`, a satori template, PNG export, and a "Share" button that opens X with prefilled text (no API needed) | You can post a card in two clicks |
| **11** | Onboarding: detect agents, show a diff of the hook config, install, guide Codex trust, clean uninstall, mic permission prompt | A fresh macOS user account goes from DMG to the first rope drop in under 3 minutes |
| **12** | Packaging: bundle the `belayd` binary in the `.app`, sign both, **notarize**, build the DMG, and set up GitHub Releases. Landing page in Next.js on Vercel. | The DMG opens without Gatekeeper warnings on another Mac |
| **13** | Launch assets: a 20-second hero video with sound, a README GIF, the Show HN text, and the Product Hunt draft. Fix the top 5 dogfood bugs. | Assets are final |
| **14** | **Launch** (see `launch.md`) | — |

**Cut line:** if Day 6 slips past Day 8:
- Drop **Codex** to v1.1.
- Drop **Always**.
- Keep Claude Code, the catch, voice deny-with-message and the share card. Those four make the clip.

## 4. Accounts and setup you need before Day 1

- **An Apple Developer Program membership** for signing and notarizing. Without it, the DMG shows scary Gatekeeper warnings, which ruins installs. The fee and how fast enrolment happens are **UNVERIFIED** here; enrol now in case it's slow.
- **Xcode** and Bun installed.
- **Name checks:** GitHub org or repo name, an X handle, and a domain for "Belay". Availability is **UNVERIFIED**; check today.
- **A test Mac or a second macOS user account** for clean-install testing.

## 5. Using Claude Code to write the Swift

- Keep the Swift surface **small and boring**: about 6 files (App, NotchPanel, ApprovalCard, CharacterView, Voice, SocketClient).
- Ask Claude Code for one view at a time. Paste in the WebSocket message types so the boundary stays stable.
- Clicky's README already gives a Claude Code prompt for getting the project building ("Clone … read the CLAUDE.md … getting it building in Xcode"). Use that on Day 1.
- Put a `CLAUDE.md` in the Belay repo: architecture, the protocol, "never auto-allow", and "fail open to the terminal".

## 6. Risks and mitigations

| Risk | Likelihood | Mitigation |
|---|---|---|
| Swift and notch window issues eat days | High | Fork Clicky for scaffolding. Keep the logic in TS. The Day 3 panel is plain SwiftUI. |
| Hook behaviour differs from the docs (holding responses, timeouts) | Medium | Day 1 spike is the go/no-go |
| Codex trust step confuses users | Medium | Onboarding screen with exact steps. Claude-only still demos fine. |
| Microphone and speech permission friction | Medium | Ask only on first push-to-talk, with a clear sentence explaining why |
| **Aria or NotchNook ships the same "voice steer" headline** | Medium–high | Your moat is the character, the catch moment and open source. Launch on Day 14; don't slip. |
| Anthropic or OpenAI change hook schemas | Medium | Pin tested versions in the README. Keep the schema parsing in one TS module. |
| Security criticism ("a hook that can approve shell commands") | Certain on HN | 0600 Unix sockets (no network port at all), no remote access, open source, fail-open-to-prompt. Say all of this in the README. |
| Trademark or brand complaints | Low | No vendor logos or mascots. Use "works with Claude Code and Codex" wording, as Aria does. |

## 7. Definition of shipped (Day 14)

- A signed, notarized DMG on GitHub Releases. Repo is public with an MIT licence and a GIF in the README.
- Supports Claude Code (full) and Codex (allow, or deny with a message).
- F1–F8 work on a clean Mac.
- The landing page is live, with the privacy line.
- The hero video is recorded.

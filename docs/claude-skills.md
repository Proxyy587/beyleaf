# Claude Code skills for Belay

Project skills live in `.claude/skills/<name>/` and load automatically in Claude Code. Third-party skills are copied
verbatim with their licence and a `SOURCE.md` (upstream, commit, file hashes, why). Chosen 2026-11-24.

| Skill | What it's for | Source and licence |
|---|---|---|
| `belay` | Repo rules, playbooks (commit, vendor, ADR, feature, crew), `verify-repo.sh` | Ours (MIT) |
| `belay-design` | Design system and anti-slop review for every Belay surface | Ours (MIT) |
| `swiftui-macos` | **New.** Build, run, test and verify `apps/mac` with the CLT only; the SwiftUI/AppKit/Core Audio patterns this app uses (tokens, optical alignment, Settings components, Swift 6 concurrency, lifecycles, screenshots, CPU, logs) | Ours (MIT) |
| `dusk-feel` | **New.** The dusk bot look, in our own words: tonal borderless surfaces, neutral pill buttons, a radius ladder, one motion per kind (with SwiftUI curves), quiet lowercase copy, and its screenshot-audit method. `docs/design.md` wins where Belay differs on purpose | Ours (MIT), from a study of dusk bot (ADR 0018); no dusk bot text or code |
| `frontend-design` | Design-quality guidance for new web UI: `apps/web`, the landing page, share cards. `dusk-feel` gives it Belay's look; `docs/design.md` wins where they differ (mono status lines, `A · B` meta) | anthropics/skills @ e4bb5d9, Apache-2.0 |
| `verification-before-completion` | **New.** No "done" without fresh evidence: build output, test output, a screenshot looked at | obra/superpowers @ 22f0b46, MIT |
| `dxe-apple-native-ui` ("apple-native-ui") | **New.** Native Apple behaviour: system controls, VoiceOver, state ownership, version gates, and a macOS workflow (menu bar utility, keyboard, windows, pasteboard). Its Xcode/XCUITest checks are limits for us (ADR 0013) | kemiljk/skills @ 32a9154, MIT |
| `agent-browser` | **New.** Lets an agent look at web pages: screenshot reference sites, read computed fonts and colours, QA `apps/web` later. The stub loads its real guide from the installed CLI (`npm i -g agent-browser@0.44.0`; uses Brave or Chrome via `AGENT_BROWSER_EXECUTABLE_PATH`, see `SOURCE.md`) | vercel-labs/agent-browser @ f0a9835, Apache-2.0 |
| `improve-codebase-architecture` + `codebase-design` | **New.** Run on purpose only (`/improve-codebase-architecture`): finds shallow modules, proposes deeper ones as an HTML report, then asks before changing anything. Use before big steps (`belayd`, Crew). `codebase-design` supplies its vocabulary. Three small edits for our paths and missing helpers, listed in `SOURCE.md` | mattpocock/skills @ d653911, MIT |

Built into Claude Code already, so not copied: `/code-review` (correctness review), `/simplify` (cleanups),
`/security-review`, `claude-api`, and `skill-creator` (via the anthropic-skills plugin).

## Considered but skipped
- **Hallmark** (Nutlope, MIT plugin): tried 2026-11-25, then removed at the owner's request. Its no-waiver floor bans
  tracked-caps labels and `A · B` meta, which Belay's status lines use, so it fought `docs/design.md`.
- **webapp-testing** (Anthropic, Apache-2.0): ships Playwright helper scripts; `apps/web` doesn't exist yet. Revisit then.
- **mcp-builder** (Anthropic, Apache-2.0): ships Python scripts; Crew's MCP proxy is v0.2 (ADR 0009). Revisit then.
- **skill-creator** (Anthropic, Apache-2.0): already available as a built-in plugin; copying it adds unreviewed scripts.
- **doc-coauthoring** (Anthropic): no licence file in its folder, so its terms are unclear.
- **systematic-debugging**, **test-driven-development** (obra/superpowers, MIT): good, but debugging ships shell and
  TS helpers, and TDD assumes a test runner the CLT-only Swift build doesn't have (we use `swiftc` self-tests).
- **brand-guidelines** (Anthropic): Anthropic's own brand; Belay carries no vendor branding (AGENTS.md rule 7).
- **slack-gif-creator** (Anthropic): depends on FFmpeg (GPL-3.0 per its notices); off-topic and against ADR 0003.
- **docx, pdf, pptx, xlsx, canvas-design, algorithmic-art, theme-factory, internal-comms, web-artifacts-builder,
  discernment-nudge**: not about building Belay.
- **glassmorphism**, **ascii-animation** (iart-ai/web-animation-skills, MIT): CSS and canvas only. Belay's glass is native
  SwiftUI, so its rules live in `swiftui-macos`. Dithered and ASCII art is a website hero idea for `apps/web`; revisit then.
- **liquid-glass** skills: zakisheriff and haider-nawaz have no licence, so they're out. Armitanemati (MIT) is mostly web
  (3 SwiftUI mentions in 538 lines). Covered natively in `swiftui-macos`.
- Unvetted community collections: not read in full, so not adopted.

**Rule for adding one:** permissive licence (MIT, Apache-2.0, BSD), read the whole `SKILL.md`, no scripts unless each
is reviewed, copy verbatim with `LICENSE` and `SOURCE.md` (any Belay edit is listed there), add a row here. Keep the set small:
every skill's description is loaded into every session.

# Claude Code skills for Belay

Project skills live in `.claude/skills/<name>/` and load automatically in Claude Code. Third-party skills are copied
verbatim with their licence and a `SOURCE.md` (upstream, commit, file hashes, why). Chosen 2026-11-24.

| Skill | What it's for | Source and licence |
|---|---|---|
| `belay` | Repo rules, playbooks (commit, vendor, ADR, feature, crew), `verify-repo.sh` | Ours (MIT) |
| `belay-design` | Design system and anti-slop review for every Belay surface | Ours (MIT) |
| `swiftui-macos` | **New.** Build, run, test and verify `apps/mac` with the CLT only; the SwiftUI/AppKit/Core Audio patterns this app uses (tokens, optical alignment, Settings components, Swift 6 concurrency, lifecycles, screenshots, CPU, logs) | Ours (MIT) |
| Hallmark (plugin `hallmark@hallmark`, `/hallmark:hallmark`) | **New, replaces `frontend-design`.** Anti-slop design for **new web pages** (`apps/web`, landing page, share cards): a no-waiver floor, slop gates, `sloplint`, plus `audit` and `redesign` when named. Web only, it doesn't know SwiftUI. `docs/design.md` wins on conflicts (mono uppercase status lines, `A · B` meta) | Nutlope/hallmark v2.0.0 @ 04977e1, MIT. Installed at project scope via `.claude/settings.json`, so collaborators get it too |
| `verification-before-completion` | **New.** No "done" without fresh evidence: build output, test output, a screenshot looked at | obra/superpowers @ 22f0b46, MIT |

Built into Claude Code already, so not copied: `/code-review` (correctness review), `/simplify` (cleanups),
`/security-review`, `claude-api`, and `skill-creator` (via the anthropic-skills plugin).

## Considered but skipped
- **frontend-design** (Anthropic, Apache-2.0): removed 2026-11-25. Hallmark covers the same job in more depth, and two web-design
  skills with different rules would argue.
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
- Unvetted community collections: not read in full, so not adopted.

**Rule for adding one:** permissive licence (MIT, Apache-2.0, BSD), read the whole `SKILL.md`, no scripts unless each
is reviewed, copy verbatim with `LICENSE` and `SOURCE.md`, add a row here.

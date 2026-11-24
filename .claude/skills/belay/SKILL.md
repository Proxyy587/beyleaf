---
name: belay
description: Project skill for the Belay repo (a free, MIT macOS notch app that supervises Claude Code/Codex sessions and runs a crew of sub-agents). Use for ANY work in this repository - implementing a feature from docs/features-final.md, writing Swift in apps/mac or TypeScript in core/, vendoring code from a reference repo, recording a decision (ADR), designing crew members or tools, updating docs, changelog or commits, or answering "what's the plan / what's next / how does X work" about Belay.
---

# Belay

You are working on **Belay**: a climber in the Mac notch who "holds the rope" for coding agents. When an agent needs approval the rope drops. When it tries something dangerous Belay catches the fall. You answer by voice or keyboard. v0.2 adds a **Crew** of sub-agents (Lead, Porter, Tempo, Scout, Sketch).

## Live state

- Branch and status: !`git -C "$(git rev-parse --show-toplevel)" status --short --branch | head -15`
- Recent commits: !`git -C "$(git rev-parse --show-toplevel)" log --oneline -8`
- Unreleased changes: !`awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' "$(git rev-parse --show-toplevel)/CHANGELOG.md" | head -30`

## Non-negotiable rules (ADR in brackets)

1. **Swift renders and touches macOS; TypeScript (`belayd`) decides.** No product logic in Swift. [0001]
2. **Shell ↔ core speak only protocol v1.** Schemas live in `core/packages/protocol` (zod); Swift types are generated, never hand-edited. [0001]
3. **Fail open, never auto-allow.** Timeout, crash or shutdown means no decision. `allow` only from a user action or a user-made "Always" rule. [0005]
4. **Never touch agent credentials.** No reading `~/.claude` or `~/.codex` auth or session files. Engines run the user's own CLIs. [0004]
5. **No GPL code; no source-available code** (PolyForm/BSL/"personal use", e.g. dusk bot). Vendor only from `refs.lock` via `scripts/vendor.sh`. [0003, 0008]
6. **Hooks go over 0600 Unix sockets via the `belay-hook` shim.** No TCP ports. [0006]
7. **Crew goes through CrewService; one ToolHost; capability-scoped MCP proxy.** [0009, 0010]
8. **Untrusted content can't grant permission.** Tainted chains always drop the rope for outward, write-outside or shortcut actions. [0011]
9. **No vendor names or logos in Belay's branding.**
10. **The notch window is ours** (ADR 0014); the Mac app builds with SwiftPM via `apps/mac/scripts/run.sh` (ADR 0013).
11. **Unknowns stay marked UNVERIFIED.** Verify before saying done: run the test or build, or say you didn't.

## Pick the playbook for the task

| Task | Read |
|---|---|
| Any commit (always) | `playbooks/commit.md` |
| Implement a feature (A1, K3, …) | `playbooks/feature-work.md` |
| Borrow code from an upstream repo | `playbooks/vendor.md` |
| Make or change a decision | `playbooks/decision.md` |
| Add a crew member, tool or runtime | `playbooks/crew.md` |
| Find the right doc | `reference/docs-map.md` |
| Climbing vocabulary and feature IDs | `reference/glossary.md` |
| What's still unverified | `reference/open-questions.md` |

## Before you finish any task

- Run `.claude/skills/belay/scripts/verify-repo.sh`. It must pass.
- `CHANGELOG.md` → `[Unreleased]` is updated in the same commit, if the change is user-visible or a decision.
- One task, one commit, Conventional Commit subject, attribution trailer (`playbooks/commit.md`).

Full context for all agents: `AGENTS.md` (Codex reads it too). This skill adds the step-by-step playbooks.

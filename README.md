# Belay

A tiny climber who lives in your Mac's notch and holds the rope for your coding agents. When Claude Code or Codex needs you, the rope drops. When an agent tries something dangerous, Belay catches the fall, out loud. Answer by voice and the agent keeps climbing.

Free, open source (MIT), local-only. **Status: pre-v0.1.** Docs, decisions and vendored references are set up; application code starts with the Day 1 spike in [docs/build-plan.md](docs/build-plan.md).

## Start here

- **Contributors and coding agents:** [AGENTS.md](AGENTS.md) (rules, repo map, working agreement) and [CONTRIBUTING.md](CONTRIBUTING.md)
- **What's changed:** [CHANGELOG.md](CHANGELOG.md)
- **Decisions:** [docs/decisions/](docs/decisions/README.md)
- **Borrowed code:** [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `third_party/*/SOURCE.md`

## Docs

| Doc | What's in it |
|---|---|
| [docs/features-final.md](docs/features-final.md) | **Locked build list (v0.1 / v0.2 / v0.3+)** with acceptance tests |
| [docs/architecture.md](docs/architecture.md) | Processes, modules, protocol, flows, storage, security, testing |
| [docs/tech-stack.md](docs/tech-stack.md) | Stack decisions (including the Rust question) |
| [docs/build-plan.md](docs/build-plan.md) | 2-week build plan |
| [docs/crew.md](docs/crew.md) | **Crew:** sub-agent engineering spec (Lead, Porter, Tempo, Scout, Sketch) |
| [docs/features.md](docs/features.md) | Full ecosystem feature spec and design principles |
| [docs/product.md](docs/product.md) | Product concept and hero moment |
| [docs/oss-reuse.md](docs/oss-reuse.md) | Open-source code to reuse; using existing AI subscriptions |
| [docs/launch.md](docs/launch.md) | Launch and marketing plan |
| [docs/market.md](docs/market.md) | Market growth and what goes viral |
| [docs/landscape.md](docs/landscape.md) | Competitive landscape |
| [docs/pain.md](docs/pain.md) | Evidence of developer pain |
| [docs/feasibility.md](docs/feasibility.md) | What agents expose from outside |
| [docs/verdict.md](docs/verdict.md) | Build/kill call (as a business) |

## Layout

```
apps/mac  Swift shell · apps/web  site · core/  Bun workspace (belayd, protocol, rules, cards)
rules/    community rule packs · e2e/  live agent tests · third_party/  vendored upstream code
docs/     research, product, architecture, ADRs · scripts/  fetch-refs.sh, vendor.sh
```

## License

MIT. Third-party code is credited in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and keeps its own licence.

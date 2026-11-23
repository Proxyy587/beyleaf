# 0004: Use AI subscriptions only through the user's own CLIs

- **Status:** accepted (2026-11-24)
- **Context:** Anthropic does not permit third-party apps to offer Claude.ai login, route requests through Free/Pro/Max/Ultra credentials, or store session tokens. It does permit an end user to sign in to the unmodified Claude Code binary with their own subscription. OpenAI's Sign in with ChatGPT needs a partner client ID. (Sources: `docs/oss-reuse.md` §2.)
- **Decision:**
  - Belay has "engines", not logins: the user's installed `claude` CLI, `codex` CLI, a local model, or the user's own API key.
  - Belay never reads `~/.claude` or `~/.codex` credential files and never handles subscription tokens. A CI grep test enforces this.
- **Consequences:** No "Sign in with Claude" button. Before launching agent sessions ourselves (v0.2 Hands), confirm whether Anthropic's Commercial Terms apply (open question in `docs/oss-reuse.md` §2). Apply for a Sign in with ChatGPT client ID separately.

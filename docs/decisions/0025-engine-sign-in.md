# 0025: Engines sign in through the vendor's own CLI; Belay reads status from the CLI, never from files

- **Status:** accepted (2026-11-27, owner asked for dusk bot's approach)
- **Context:**
  - What dusk bot does, from its public docs, in our words: it runs each provider's official command-line agent and lets that program own the sign-in, so the user types a password only on the provider's page. It reads the CLI's status first (an existing sign-in is reused without asking), offers to install a missing CLI, opens the provider's page, shows any device code with a copy button, notices completion on its own, and gives every stage a deadline with a retry. Any CLI that speaks the Agent Client Protocol can be added as an engine. It strips other vendors' API keys from the child's environment so a CLI never bills a different login.
  - Where it differs from our rules: for Codex it keeps a copy of the token in its own folder, it downloads and runs installers for the user, it checks sign-in by sending a billed test message, and it saves API keys in a plain file. We do none of these (ADR 0004).
- **Decision:**
  1. **Status comes from the CLI's own status command** (`claude auth status --json`, `codex login status`), run with a timeout. Belay never opens `~/.claude`, `~/.codex` or any credential store (CI grep enforces it). An engine with no verified status command reports `unknown`, never a guess.
  2. **Sign-in is the vendor's command in a visible Terminal window** (`claude auth login`, `codex login`). Belay never sees the code, the password or the token. While it waits, belayd re-reads status every 2 s and stops after 5 minutes.
  3. **Install is shown, not run.** For a missing CLI Belay shows the vendor's official install command and link with a copy button. It runs no downloaded installer.
  4. **Subscription mode strips API-key variables** (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, …) from the environment of any engine process, so a stray key can't silently bill the user instead of their plan. A future API-key engine keeps only its own key, stored in the Keychain, never a plain file.
  5. **No billed test messages.** Belay checks sign-in only, not model access; a model error surfaces when a buddy first runs.
- **Consequences:**
  - A new engine is one catalog entry (binary names, status command and parser, login command, install hint, a `verified` flag).
  - `codex`, `cursor-agent` and `agy` commands are UNVERIFIED until run on a real install; the catalog marks them and the UI says "can't tell" when unsure.
  - Adds `core/packages/belayd/src/engines/` and engines messages to protocol v1.

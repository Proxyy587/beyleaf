# 0005: Fail open to the agent's own prompt; never auto-allow

- **Status:** accepted (2026-11-24)
- **Context:** Belay sits in the approval path of tools that can delete files and run shell commands.
- **Decision:**
  - If Belay is not running, slow, crashed or timing out, the hook returns **no decision** and the agent shows its own terminal prompt.
  - No code path returns `allow` without an explicit user action or a user-created "Always" rule.
- **Consequences:** The approval broker returns an empty body on timeout and on shutdown. A unit test and a lint rule guard the broker's allow paths.

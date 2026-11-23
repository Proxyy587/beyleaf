# e2e: verified continuation (A6)

Live tests: a real Claude Code and Codex session in a temp repo triggers an approval, Belay answers allow /
deny-with-message, and the test asserts the agent continued as instructed. Run before every release. Results feed the
README's support matrix.

UNVERIFIED: whether `PermissionRequest` fires in headless `claude -p`; if not, drive an interactive session through a pty.

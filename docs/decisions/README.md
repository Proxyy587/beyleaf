# Architecture decision records

One file per decision that is expensive to reverse. Status is one of `accepted`, `superseded by NNNN`, or `proposed`.
New decision: copy the newest file, bump the number, and link it here.

| # | Decision | Status |
|---|---|---|
| [0001](0001-swift-shell-ts-core.md) | Swift shell + TypeScript core, talking over a versioned local protocol | accepted |
| [0002](0002-rust-core-later.md) | Rust core deferred to v0.3, behind the same protocol | accepted |
| [0003](0003-no-gpl-code.md) | No GPL code; MIT/Apache-2.0 only, vendored with provenance | accepted |
| [0004](0004-engines-not-logins.md) | Use AI subscriptions only through the user's own CLIs | accepted |
| [0005](0005-fail-open.md) | Fail open to the agent's own prompt; never auto-allow | accepted |
| [0006](0006-unix-socket-hook-transport.md) | Hooks reach the core over a Unix socket via a command-hook shim | accepted |
| [0007](0007-dynamicnotchkit-dependency.md) | DynamicNotchKit as a pinned SwiftPM dependency, not vendored | accepted |
| [0008](0008-source-available-inspiration-only.md) | Source-available projects (e.g. dusk bot) are product inspiration only: not cloned, not read for code | accepted |

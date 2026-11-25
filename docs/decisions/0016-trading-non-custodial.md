# 0016: Trading agent is non-custodial, and the LLM never places orders

- **Status:** accepted for design (2026-11-24); implementation blocked on legal review (`docs/prerequisites.md`)
- **Context:** The user wants an agent that invests (stocks, ETFs, mutual funds) for them. That's real money and a regulated activity. LLM output can be wrong or prompt-injected (ADR 0011).
- **Decision:**
  - Belay never holds funds and never asks for withdrawal or transfer permissions. Users connect their own brokerage account through official APIs with trade-only scope. Keys live in the macOS Keychain.
  - The model reads, explains and proposes. A deterministic OrderBroker places orders only after the RiskEngine passes, plus either explicit user approval (a rope card) or an in-limits autopilot rule the user signed.
  - The default is Watch plus Paper. Autopilot unlocks only after 30 days of paper trading, behind a graduation card. A kill switch, a daily-loss stop, idempotent orders and broker reconciliation are mandatory.
  - No derivatives, margin or shorting in v1. Mutual funds only via compliant rails after legal review.
- **Consequences:** Slower to ship, safer by design. See `docs/trading.md`.

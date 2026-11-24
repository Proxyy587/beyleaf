# Belay Trading agent ("Ledger"): engineering design

**Status:** exploration. **Not scheduled.** It needs legal sign-off first (`docs/prerequisites.md`).
**Written:** 2026-11-24.

> **In one line:** a crew member that watches the markets you choose and proposes trades, or places them only inside limits you set, on **your own brokerage account**, with every order going through Belay's rope cards, a risk engine and a kill switch.

## 0. Hard truths first

1. **Belay never holds money.** There's no "submit your wallet to Belay". The user connects their *own* brokerage account through the broker's official API, with trading permission only and **never withdrawal or transfer** permission. Funds stay at the regulated broker.
2. **No promised returns.** Automated trading loses money too. The UI never says "grow your money"; it says what the rules did and what it cost.
3. **The user is in control, legally and practically.** Belay is software the user runs on their own account, with rules they configure. It isn't an adviser or a fund manager. **Whether that framing holds in each country is a question for a lawyer** (prerequisites).
4. **Regulation is real.**
   - **India:** SEBI's retail algo framework (circular of 4 Feb 2025, mandatory for brokers from 1 Apr 2026, per secondary sources; **verify on sebi.gov.in**) makes the broker the principal for API algo trading. It also requires exchange **Algo-IDs**, **static-IP whitelisting** and broker-controlled API keys, and registration of self-built algos above an order-rate threshold.
   - **US:** paper and live trading share one API at brokers like **Alpaca** (commission-free US stocks/ETFs via API, free paper environment, per its own pages).
   - **Mutual funds** (India) usually need distributor or adviser rails. **UNVERIFIED**, so it's out of scope until legal review.

## 1. Modes (the user picks; default is the safest)

| Mode | What happens | Default |
|---|---|---|
| **Watch** | Ledger reports: portfolio, prices, news on your holdings, rule triggers. No orders. | ✅ first run |
| **Propose** | Ledger drafts orders. **Every order is a rope card** you approve by click or voice. | |
| **Autopilot within limits** | Ledger places orders **only** inside a signed rule set (instrument list, max order size, max daily spend, max daily loss, max position %). Anything outside the limits becomes a rope card. Daily summary. | locked until 30 days of paper trading |
| **Paper** | Any mode against the broker's paper or sandbox environment | ✅ until the user graduates |

## 2. Architecture (fits the Crew design, `docs/crew.md`)

```
Belay.app (Swift)  ── rope cards · notch live activity (P&L, fills) · kill switch
      │ protocol v1
belayd (TypeScript)
  CrewService ─ member "Ledger" (runtime: your engine; prompts only *propose*, never place)
  TradingService
   ├─ BrokerAdapters   Alpaca (US, paper+live) · Indian brokers (SEBI-framework APIs, static IP) · Fake
   ├─ MarketData       broker feeds; delayed data clearly labelled
   ├─ Strategy         deterministic rules (DCA, rebalancing, stop-loss, take-profit); LLM only explains/proposes
   ├─ RiskEngine+      hard limits · daily loss stop · position caps · instrument allow-list · market-hours check
   ├─ OrderBroker      idempotent orders, client order ids, retries, reconciliation with broker state
   ├─ Ledger store     SQLite: orders, fills, positions, P&L, every decision with its reason
   └─ Secrets          broker keys in the macOS Keychain (never in SQLite or logs; vendored redact.ts)
```

**Key rules:**
- **The LLM never places orders.** It reads, explains and *proposes*. A deterministic `OrderBroker` places orders only after RiskEngine passes, plus either the user's approval or an in-limits autopilot rule. This is the same taint principle as ADR 0011: news, web pages and messages can't trigger trades by themselves.
- **Idempotency and reconciliation.**
  - Every order gets a client order id; retries never double-buy.
  - On start, and every N minutes, local state is reconciled with the broker's positions and orders. The broker is the source of truth.
- **Kill switch.** "Belay, stop trading" or one button: cancel open orders, disable autopilot, revoke the session. Also triggered automatically by the daily-loss limit, repeated API errors or a reconciliation mismatch.
- **Rate limits and Algo-ID** (India): stay far below registration thresholds unless registered. Tag orders as the broker requires.

## 3. Safety limits (defaults; the user can tighten, and loosening needs a confirmation card)

| Limit | Default |
|---|---|
| Max single order | 2% of portfolio |
| Max daily new exposure | 10% of portfolio |
| Daily loss stop | 2% of portfolio, which halts autopilot for the day |
| Instruments | Explicit allow-list (e.g. broad ETFs). No derivatives, margin or shorting in v1. |
| Market hours only | Yes; no extended hours in v1 |
| Cool-off | No autopilot for 30 days of paper trading, then a graduation card |

## 4. Experience

- **Notch live activity:** today's P&L in mono (green or red only as status), fills as brief alerts ("Bought 3 × NIFTYBEES"), a rope card for each proposal.
- **Base camp tab:** holdings, rule set, the full decision log ("why each order happened"), and a CSV export for tax time.
- **Words:** "Proposed: buy 2 × VTI (₹/$ amount). Reason: monthly DCA rule. Within limits." Never hype.

## 5. Phasing

| Phase | Scope |
|---|---|
| T0 | Legal review, broker choice, paper account |
| T1 | **Watch mode** + paper trading with a Fake and an Alpaca paper adapter; risk engine and log |
| T2 | **Propose mode** with rope-card approvals (paper, then live with tiny limits) |
| T3 | Autopilot within limits, after graduation; Indian broker adapter after a framework compliance check |
| Later | Mutual funds/SIPs only through compliant rails, after legal review |

## 6. Open questions

1. Legal status per country of a user-configured trading assistant in a free open-source app.
2. Which Indian broker APIs are live under the SEBI framework, plus their static-IP and Algo-ID process for self-built tools.
3. Market-data licensing for showing prices in the notch.
4. Tax reporting formats per country.

# What only a human can do

**Written:** 2026-11-24.

Things the agents can't do for you: accounts, money, legal calls, physical hardware, taste. Ordered by when they block work. Tick them off here (edit this file) so every agent session sees the status.

## Now (blocks the next build steps)

| ✓ | Task | Why | How |
|---|---|---|---|
| ☐ | **Install Bun** | The core daemon `belayd` (hooks, approvals, crew) is TypeScript on Bun | `curl -fsSL https://bun.sh/install \| bash`, then pin the version in `.bun-version` |
| ☐ | **Install Xcode** (optional, recommended) | Not needed to build today (ADR 0013). Needed for previews, Instruments (performance), asset catalogs and notarization tooling. | App Store → Xcode, then `sudo xcode-select -s /Applications/Xcode.app` |
| ☐ | **Install cmake** | To build `mediaremote-adapter` (BSD-3) for now playing from **any** app (browsers, YouTube, Podcasts) with artwork | `brew install cmake` |
| ☐ | **Grant Belay's permissions when asked** | Automation → Music/Spotify (controls, artwork). Later: Microphone + Speech Recognition (voice), Accessibility (global shortcuts, window layouts), Location (to show the Wi-Fi network name). | System Settings → Privacy & Security |
| ☐ | **Test on real hardware** | Hover feel, the live activity while music plays, alerts when plugging in power, behaviour on an external display or a Mac without a notch | Play a song, plug or unplug power, connect a monitor; report what feels off |
| ☐ | **Review `initial-test` and merge it** | Nothing has reached `main` on GitHub | github.com/Proxyy587/beyleaf/pull/new/initial-test |

## Before you share builds with anyone

| ✓ | Task | Why |
|---|---|---|
| ☐ | **Join the Apple Developer Program** (paid, yearly) | Developer ID signing plus notarization; without it macOS warns everyone, and permissions reset after every update. Fee and processing time: check developer.apple.com. |
| ☐ | **Create a "Developer ID Application" certificate** in your Keychain | `run.sh` signs with it automatically once it exists (Perch's pattern) |
| ☐ | **Choose the final name and check it** | "Belay": GitHub org, domain, X handle, and a trademark search. The repo is called `beyleaf`; decide which is the brand. |
| ☐ | **Brand art** | The pixel climber (5 states × ~4 frames), app icon, sounds. Commission, draw, or approve a set we generate. Must be original. |
| ☐ | **Pixel font licence** | Confirm Pixelify Sans (or your pick) is OFL before we bundle it |

## Before agent features ship (v0.2)

| ✓ | Task | Why |
|---|---|---|
| ☐ | **Ask Anthropic, or read the Commercial Terms** | Whether a free app that *launches* your own Claude Code install needs them (`docs/oss-reuse.md` §2) |
| ☐ | **Apply for a "Sign in with ChatGPT" client ID** | Lets Belay use a user's ChatGPT plan directly (`docs/oss-reuse.md` §2) |
| ☐ | **Install the Codex CLI** on your Mac | Needed to test Codex hooks and the Lead crew member (it's not on PATH today) |

## Before the trading agent (Q, `docs/trading.md`)

| ✓ | Task | Why |
|---|---|---|
| ☐ | **Talk to a qualified financial-regulation lawyer** in each country you'd offer it | Automated trading on users' money is regulated. Belay must stay a tool the user controls, not an adviser or fund manager. |
| ☐ | **Open a brokerage account with API access** (yours, for testing) | India: a broker whose API supports the SEBI retail-algo framework (static IP, Algo-ID). US: Alpaca or similar (free paper trading). |
| ☐ | **Get a static IP** (India) | The SEBI framework requires whitelisted static IPs for API trading (per secondary sources; verify on sebi.gov.in) |
| ☐ | **Decide markets and products** | Stocks/ETFs first. Mutual funds need registered distributor or adviser rails in India (**UNVERIFIED**; legal check). |
| ☐ | **Paper-trade for a meaningful period** before any real money | Required by our own design (Q1) |

## Launch

| ✓ | Task |
|---|---|
| ☐ | Accounts: X (brand), Product Hunt, Hacker News (aged account helps), Reddit |
| ☐ | Record the 20-second hero video (needs the agent features from v0.1) |
| ☐ | Landing-page domain plus Vercel account |

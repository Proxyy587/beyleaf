# 0008: Source-available projects are product inspiration only

- **Status:** accepted (2026-11-24)
- **Context:**
  - dusk bot (https://dusk.bot, repo `DuskBotAI/duskbot`, 578 stars when checked on 2026-11-24) is a fork of OpenMausBot.
  - Its own licence page says it is **"source-available under the PolyForm Noncommercial License 1.0.0. Source-available does not mean open source."** Commercial use, including "inside a product", needs a paid licence from its makers.
  - Belay is MIT, which permits commercial use. Code derived from dusk bot can therefore never be in Belay. The parts dusk bot inherited from OpenMausBot remain Apache-2.0 upstream, and we already pin that upstream (`refs.lock`).
- **Decision:**
  - Projects under non-OSI, source-available licences (PolyForm, BSL, SSPL, "free for personal use", and similar) are **not cloned into `refs/`, not added to `refs.lock`, and their source is not read for implementation.** dusk bot is the first.
  - We may study their **public product pages and docs** for product ideas (what a feature does and why), recorded in our own words.
  - Where a source-available project derives from an open-source upstream, we read and vendor from **that upstream** instead (for dusk bot: OpenMausBot @ `310e731e`).
- **Consequences:** A clean-room line: Belay's code can't be challenged as derived from dusk bot. `docs/crew.md` cites dusk bot only for product inspiration, with links to its public pages.

# What other notch apps do, and what Belay's expanded view takes from them

**Written:** 2026-11-27. **Read:** `refs/perch` (MIT), `refs/avo` (MIT), `refs/DynamicNotchKit` (MIT); Boring Notch by its README only (GPL, so product-level, no code). Everything below is described in our own words; no code was copied.

## What each one does with "more room"
| App | What the larger surface is | Idea worth taking |
|---|---|---|
| **Perch** (agent supervisor) | Not a bigger card but a different surface: a keyboard-driven **list of every session**, grouped *Needs you / Today / Earlier*, with a type-to-filter field and one key to jump. A fixed panel (about 480 × 440), one surface at a time, chosen by a small state machine (card, list, new session, settings). Requests show as small wings until answered. | Group by urgency, not by name. **What needs you comes first, everywhere.** Keep the panel a fixed, calm size. |
| **Avo** (notch assistant) | A **side tab** on the screen edge that slides out into a 300 pt sidebar of long-running tasks grouped *Working / Done / Earlier*, separate from the notch's own cards (confirmation, question, draft, task, reminder). | Long-running work deserves its own place with a history, not a widget among clocks. |
| **DynamicNotchKit** | A shell: compact, expanded and hidden states, with the content left to the app. | Nothing to add; confirms that expanded is a *mode*, not a scale. |
| **Boring Notch** (README) | A fixed set of views (music, calendar, shelf, mirror); customizable layout is still a roadmap item. | Our user-arranged widgets stay the edge here. |

## What was wrong with Belay's expanded view
It added one grid column. Same widgets, a little more room, and nowhere for agents, tasks or schedules to live: the Agents page was three widgets stacked.

## What expanded is now
Compact stays a **glance**: one page at a time, small dots at the bottom, quick to read and fast to leave. Expanded is a **workspace**:
1. **A page rail** down the left: every page by name, the current one lit, a badge where something waits on you. It replaces the dots.
2. **Four grid columns** (compact has two), so two wide widgets share a row and four small ones fit. Widgets keep their size; there are simply more of them on screen.
3. **A "needs you" bar** on every page (taken from Perch's rule that what needs you comes first): the first task waiting for your plan approval, a spend or your payment, with its buttons.
4. **Agents becomes its own layout**: crew on the left, the conversation in the middle, **Tasks and Schedule** (two tabs) on the right. Tasks are what is being done; Schedule is what will be, and each routine makes a task for you to approve when its time comes (ADR 0026).
5. The page width grows to fit (about 940 pt, capped), the content area is scrollable if a page is taller than the room, and reduced motion still cross-fades.

## Not taken (and why)
- Perch's WebView-based UI: we render natively for CPU and memory.
- Avo's edge tab: a second always-on window costs idle CPU; the rail and the "needs you" bar give the same job inside the notch. Revisit if Agents outgrows the notch.
- Perch's keyboard list with filter: good for many sessions; add it with the session bus (ADR 0024 phase 1).

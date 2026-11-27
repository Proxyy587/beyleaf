# 0026: Buddies and tasks exist only because you (or a buddy you made) asked; money is never autonomous

- **Status:** accepted (2026-11-27, owner asked for dusk bot's model: buddies are made on request, can make buddies, and share context)
- **Context:**
  - In dusk bot's setup, sub-agents are not created automatically. The user can make one, or another sub-agent can, and they can share context and message each other.
  - The owner also asked for goal tasks on their own computer: "open my browser and play music", "book flights", and "start trading with my money and don't stop until the amount is reached".
- **Decision:**
  1. **The crew starts as beepo alone.** beepo can't be removed. Every other buddy is made by you, or by a buddy you made, and the notch shows it ("made by …").
  2. **Spawning is bounded.** At most 8 buddies; one of each character; a buddy may make at most 3; a buddy made by a buddy can't make more; a maker can't give more reach (observe, errands, hands, sandbox) or freedom (ask, edits, routine) than it has. Removing a buddy removes what it made.
  3. **Buddies talk and share, in the open.** Messages between buddies are recorded in the pair's thread. A shared notebook (30 notes) is readable by every buddy. A chain of 6 buddy-to-buddy messages with no word from you stops and waits for you.
  4. **A task is a goal in steps you approved.** It is made only by you. It runs nothing until its plan is approved. Steps that spend, send or trade ask every time, with no "Always". A `payment` step hands the page to you: Belay never types card or bank details.
  5. **Hard limits** (steps, minutes, money) can't be raised by the task, and hitting one stops it. A goal about money with no spending limit is refused before any plan. Every task ends by finishing, by a limit, or by your stop; there is no "until it reaches X".
  6. **Trading is off.** A trading goal or a plan with a trade step is refused. It needs a broker connection and a legal check first (`docs/trading.md`); even then, orders go through the rope one by one.
- **Consequences:**
  - The policy lives in `core/packages/belayd/src/crew/registry.ts`, `talk.ts` and `tasks/machine.ts` as pure functions, with tests that pin each rule. The shell only asks and shows.
  - Planning and carrying out steps need the engine runtime and the Mac hands (docs/buddies.md phases 3 and 6). Until then a task stops at "planning", and the shell says so instead of pretending.

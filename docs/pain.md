# Belay: evidence of pain

**Question:** Do developers really complain about supervising coding agents? The categories checked were runaway agents, unreviewable diffs, lost context, not knowing what the agent did, cost surprises, and approving blindly.

**Research date:** all sources were read on **2026-11-23**.

**Window:** the last 6 months (about 2026-05-24 onward) was preferred. Older items are marked.

## Method and reach

- **Hacker News:** comments and threads were read through the official HN Algolia API (`hn.algolia.com/api/v1/items/<id>` and `/search`). Each quote below links to its comment and gives the date and the author's handle. Quotes are verbatim; "…" marks where I truncated.
- **GitHub issues:** pages on `anthropics/claude-code` were loaded directly. Reaction counts were read from the page's embedded data.
- **Reddit: no evidence collected.** `reddit.com` returned HTTP 403 to anonymous requests, and the search tool refuses the domain. I did not try to get around the block. **Nothing in this doc comes from r/ClaudeAI, r/ExperiencedDevs or r/LLMDevs.** That is a real gap.
- **X/Twitter: not reached.** No quotes from X.

---

## 1. Approving blindly / approval fatigue: **strongest category**

**Vendor data (Anthropic, not independent):** "Auto mode is now the default in Claude Code", published 2026-08-07, https://claude.com/blog/auto-mode-default-in-claude-code

> "users approve 97% of permission prompts in Claude Code"

> "As of June 2026, 49.5% of active CLI users have manually created a Bash allow-rule"

> "62% of users have used bypassPermissions or clicked "don't ask again" on Bash, and 25% of interactive sessions start in bypass permissions mode"

> "In a controlled experiment with 1,053 paid professional testers, human review caught just 13.6% of dangerous commands, while auto mode caught 89%."

⚠️ **Caveat:** this is Anthropic arguing for its own product change. The tester study ran through a "research vendor", is not peer-reviewed, and the raw data is not published. It is still the largest dataset available, and it cuts against Belay. Anthropic's answer to blind approval is **fewer human approvals**, not better approval UX.

**HN thread:** "Claude Code's 'Don't Ask Again' exposes passwords in 1,122 public GitHub files", 629 points, 424 comments, 2026-11-07, https://news.ycombinator.com/item?id=50407882

- Kim_Bruning, 2026-11-08, https://news.ycombinator.com/item?id=50409545
  > "Compare approving every step manually: at first you read everything the llm proposes carefully, convinced that you'll catch it out. After a while you get faster and faster until at some point you find yourself hitting "approve" the second the text appears, long before you actually could absorb what…"
- 40four, 2026-11-08, https://news.ycombinator.com/item?id=50410635
  > "This is the conundrum we find ourselves in. Do we submit to approval fatigue and press "Don't ask again"? Because that's the dream. We all wish we could just trust the agent to do the task start to finish, unsupervised. But this is the downside. It might be fine 99% of the time, but 1% of the time y…"
- A counter-view. prmph, 2026-11-08, https://news.ycombinator.com/item?id=50412276
  > "No, this is the way I have worked for a long time, and I have not suffered from any approval fatigue."
- Another counter-view, pointing toward sandboxing rather than better approval. coldtea, 2026-11-08, https://news.ycombinator.com/item?id=50414014
  > "A strictly enforced sandbox with sane defaults (for example ~/.ssh), that acts as a hard OS level limit, and not just as a suggestion to the agent, would not have "appr[oval fatigue]"…"
- bcherny, 2026-11-07, https://news.ycombinator.com/item?id=50408237
  > "Auto mode is significantly safer than manual approval in practice."
  
  The handle matches Claude Code's lead at Anthropic, but that identity is **UNVERIFIED** here. Either way it reads as an insider position.

**HN thread:** "Auto mode is now the default in Claude Code", 292 points, 313 comments, 2026-08-10, https://news.ycombinator.com/item?id=49239021

- SchemaLoad, 2026-08-10, https://news.ycombinator.com/item?id=49239838
  > "These tools prompt me to review an absurd number of very complex bash commands where there is realistically no way to carefully review them. I just want to put the thing in a box with the code and let it run any number of commands on the code without prompting."
- lukan, 2026-08-10, https://news.ycombinator.com/item?id=49239466. The official feature already covers this need.
  > "Another nice option to do this while staying in control, is activate /remote-control and approve from mobile while walking around."

**GitHub issues:**

- **#30882**, "Permissions reset every session resume — causes approval fatigue and safety risk". Opened 2026-03-05 (older than 6 months). Closed. **2 👍.** https://github.com/anthropics/claude-code/issues/30882
  > "This trains users to blindly approve without reading, which is the opposite of the permission system's intent"
- **#75090**, "permission prompts cause focus theft and silent file corruption in IDE". Opened 2026-07-07. Closed. **0 👍.** https://github.com/anthropics/claude-code/issues/75090
  > "every shell command — even read-only ones like listing a directory or viewing a file — raised an authorization prompt. During inventory-heavy work that meant a prompt every few seconds"

⚠️ **Thin:** both issues have tiny reaction counts (0–2). These are individual reports, not demonstrated mass demand.

## 2. "Which agent needs me?" / approving from elsewhere

**GitHub issues:**

- **#70591**, "Centralized Permission & Approval Notifications for Multi-Agent Workflows". Opened 2026-06-24. Closed. **0 👍.** https://github.com/anthropics/claude-code/issues/70591
  > "when multiple agents are active, permission requests and approval prompts appear only in their respective terminal sessions. This requires users to constantly switch between…"
- **#60433**, "Mobile notification and remote approval for permission prompts". Opened 2026-05-19. Closed. **0 👍.** https://github.com/anthropics/claude-code/issues/60433
  > "the user must be physically at their computer to approve it. This blocks execution and wastes time, especially for tasks that run unattended."
- **#32952**, "Notification hooks for permission_prompt should include tool details". Opened 2026-03-10 (older than 6 months). **3 👍.** https://github.com/anthropics/claude-code/issues/32952
- **#18453**, "Permission Prompt Hook". Opened 2026-01-16 (older than 6 months). **0 👍.** https://github.com/anthropics/claude-code/issues/18453
  > "there's no hook that fires when Claude Code is blocked waiting for user permission approval"
  
  This has since been addressed: the hooks reference now lists a `PermissionRequest` event that can allow or deny.

**HN comments:**

- cpcdoy, 2026-11-06, "Ask HN: What's your current AI agentic setup?", https://news.ycombinator.com/item?id=50399014
  > "I'd have lots of terminal tabs open which quickly became annoying and inefficient to keep track of."
- yakkomajuri, 2026-11-05, same thread, https://news.ycombinator.com/item?id=50378756
  > "I never hit limits since realizing that trying to have too many agents running at once just wasn't effective."

  This person solved the problem by running fewer agents, not with a tool.
- tohuw, 2026-07-19, Show HN for Huginn, https://news.ycombinator.com/item?id=48970488
  > "I became weary of furiously tabbing through Claude and Codex sessions, so I put Claude to work building a local-only console…"

  The thread had 1 comment.

⚠️ **Read carefully:** the issues have **0 reactions each**, and most were closed. #60433 and #70591 are effectively served now by Remote Control and by the third-party notch apps in `landscape.md`. The repeated pattern of a developer feeling the pain and building their own free tool appears several times. That signals the pain is real but **cheap to self-solve**, which is bad for monetisation.

## 3. Unreviewable diffs / review as the bottleneck: **real, but not the Belay problem**

**HN thread:** "Harvard researchers find AI coding agents shifted the bottleneck to code review", 331 points, 469 comments, 2026-11-17, https://news.ycombinator.com/item?id=50538303

⚠️ The linked article (complexdiscovery.com) returned a Cloudflare block to my fetch. The underlying study's status (paper, preprint or working paper) is **UNVERIFIED**. Only the HN discussion was read.

- diego_moita, 2026-11-18, https://news.ycombinator.com/item?id=50540233
  > "In the scale that AI produces code, it isn't feasible to have humans reviewing it. And, frankly, reviewing code sucks big time."

**HN thread:** "How the Claude Code team does code review", 488 points, 464 comments, 2026-10-16, https://news.ycombinator.com/item?id=50122951

- leoqa, 2026-10-16, https://news.ycombinator.com/item?id=50123567
  > "review is still slow; I currently have 40 PRs open"

**HN thread:** 2026-08-29, https://news.ycombinator.com/item?id=49488365. Two opposite workflows appear here, which matters for product design.

- jurgenburgen, https://news.ycombinator.com/item?id=49497305
  > "You're reviewing at the wrong layer if you're approving / rejecting each individual tool call that modifies source code. Look at the finished piece of work…"
- RetpolineDrama, https://news.ycombinator.com/item?id=49491487
  > "It's 10x more productive to watch the thinking traces and edits in real time and steer the model appropriately."

⚠️ **Caveat:** the review pain is about PRs and diffs, a problem owned by GitHub, code-review bots and Anthropic's own review tooling. A session supervisor does not obviously solve it.

## 4. Runaway / destructive agents: **vivid, but individual incidents**

- **#95426**, "Claude Code deleted ~600GB: unprompted `rm -rf` on a substitution that resolved to a drive root". Opened 2026-09-18. **Open. 0 👍.** https://github.com/anthropics/claude-code/issues/95426
  > "Because stderr was redirected to /dev/null, it produced no visible output and ran for roughly 35 minutes before anyone noticed."
- **#49129**, "Claude Code executed rm -rf and permanently deleted ~1500 files / ~50GB". Opened 2026-04-16 (just outside the window). **0 👍.** https://github.com/anthropics/claude-code/issues/49129
- **#43887**, "deleted user-created files without confirmation". Opened 2026-04-05 (outside the window). **0 👍.** https://github.com/anthropics/claude-code/issues/43887
  > "Claude Code deleted 18 user-created files (6 hours of work) without requesting explicit user confirmation."
- **#14081**, "Claude deleting files without requesting permission". Opened 2025-12-15 (outside the window). **0 👍.** https://github.com/anthropics/claude-code/issues/14081

⚠️ **Thin:** these are memorable anecdotes with **zero reactions each**. The #95426 detail ("ran for roughly 35 minutes before anyone noticed") is the best single argument for live supervision. Note, though, that it was **unprompted**: no approval UI would have shown it unless one was running in manual mode.

## 5. Not knowing what the agent did

- wiether, 2026-09-06, https://news.ycombinator.com/item?id=49584166
  > "it you let the AI go free on a server, you mostly have no idea what it did and where"
  
  This is about server ops, not coding sessions in a repo.
- bradfa, 2026-08-10, https://news.ycombinator.com/item?id=49241276
  > "I run in manual mode not out of rogue agent or token waste concern but because I want to effectively pair program with the agent. I need to understand what is happening along with the how and why."

⚠️ **Thin:** I found few explicit "I don't know what it did" complaints about coding sessions. A plausible reason is that git history already answers most of it. The same commenter (wiether) says: "I'm mostly fine letting AI write code because its easily auditable and you can follow changes through the Git history."

## 6. Lost context on long runs

- BoorishBears, 2026-07-20, https://news.ycombinator.com/item?id=48977724
  > "models in Codex get briefly lost on where it is in the plan post-compaction. If it was in the middle of a test it often tries to resume the test from the start"
- tobias2014, 2026-10-14, https://news.ycombinator.com/item?id=50080859
  > "There are many times where I had to force it…"
  
  The comment is about forced compaction in Gemini.
- A counter-view. edg5000, 2026-08-18, https://news.ycombinator.com/item?id=49343304
  > "Compaction is seamless for me."

⚠️ **Thin, and owned by the model vendors.** An external supervisor cannot fix compaction.

## 7. Cost surprises

- _fat_santa, 2026-06-02, under "Uber caps employee AI spending after blowing through budget", https://news.ycombinator.com/item?id=48376726
  > "unless you're running ralph loops on Opus with extended thinking, it's very hard to blow through more than $200/mo."
  
  This argues the cost problem is smaller than it looks for individuals.
- **Demand proxy:** `ccusage` gets **226,118 npm downloads/week** and has **19,557 stars**. Cost visibility is wanted, and is already served for free. Aria has a "Budget guard". Conductor's changelog headlines 0.96.0 as "Know what you're spending" and 0.98.0 as "See where your usage goes".

⚠️ No independent, dated individual cost-surprise complaint was found in this pass. **Evidence is thin.**

## 8. The meta-signal: "brain fry"

**HN thread:** "How I'm fighting the AI brain fry", 317 points, 216 comments, 2026-11-08, https://news.ycombinator.com/item?id=50416363

- wallstop, 2026-11-08, https://news.ycombinator.com/item?id=50416761
  > "The author's problem is that the are doing too many parallel agent things. It's very interesting that their solution space is "keep doing tons of parallel stuff, but with different tooling" instead of... "do less parallel stuff (and provide stronger attention)"."

This is a pointed critique of the whole "supervise many agents" category, from the audience Belay would sell to.

---

## Honest read of the evidence

| Pain | Real? | Independent evidence strength | Already served? |
|---|---|---|---|
| Approving blindly | **Yes** | Strong on HN (multiple 290–630-point threads); Anthropic's numbers are vendor data | **Yes.** Anthropic's response is auto mode by default (fewer approvals). Approval UIs exist in 7+ tools. |
| "Which agent needs me" | Yes | Moderate. Many self-built tools, but 0-reaction issues. | **Yes**, heavily (`landscape.md` sections 1–2) |
| Review bottleneck | **Yes** | Strong | Not by session supervisors. It is a PR/code-review problem. |
| Runaway/destructive | Yes | Vivid anecdotes, 0 reactions | Partly, by auto mode, deny rules and sandboxes. Aria has undo. |
| Don't know what it did | Weak | Thin; git covers most of it | Replay viewers exist (Claudoscope, claude-trace-replay, Aria laps) |
| Lost context | Yes | Thin | Not addressable from outside the agent |
| Cost surprises | Weak for individuals | Thin | **Yes** (ccusage, Aria, Conductor) |

**Bottom line:** the pain is real, and the loudest form (approval fatigue) is being solved by the agent vendors removing approvals, not by better approval UX. People who feel the rest of the pain mostly build their own free tool in an afternoon. I found **no evidence of willingness to pay** for supervision specifically. The clearest data point runs the other way: Vibe Kanban, with about 29k stars, shut down its company because "the vast majority are free users".

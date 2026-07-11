# Trovara Launch — Research Brief

**Phase covered: Day 1 — Stabilize · Date: 2026-07-11**

Day 1 is the earliest phase with an unchecked item. Three of four tasks are done (`flutter analyze` clean, `patrol_test` green, P0/P1 triage). The only remaining task is **"Lock feature set (freeze scope)."** Everything downstream (Day 2 QA, Day 4 release build, Day 5 store listing) assumes a frozen scope, so this is the correct next work session. It's a decision task more than a coding task — the goal below is to make the decision fast and make it stick.

---

## Task: Lock feature set (freeze scope)

Broken into three concrete sub-steps: (1) decide what's in vs. explicitly out, (2) record and publish the freeze, (3) set up a lightweight process so mid-sprint ideas don't reopen it.

### Sub-step 1 — Decide the frozen feature set and an explicit non-goals list

Options:

- **MoSCoW (Must / Should / Could / Won't).** Pro: fast, forces the uncomfortable "Won't-have" conversation that actually prevents creep; well-suited to a fixed deadline. Con: no effort/impact math, so it can hide the true cost of a "Should." ([MoSCoW for MVP](https://tekxai.com/moscow-method-for-mvp-features/), [Product School](https://productschool.com/blog/product-strategy/moscow-prioritization))
- **RICE (Reach × Impact × Confidence / Effort).** Pro: quantified, good for ranking a long backlog. Con: overkill for a 3–7 day freeze; needs data/estimates you don't have pre-launch. ([RICE vs MoSCoW 2026](https://www.mvpexpert.com/blog/rice-vs-moscow-the-ultimate-2025-guide-to-mvp-feature-prioritization-frameworks))
- **"Ship the wedge only" gut-check.** Pro: fastest; anything not serving local-first privacy + AI-over-your-notes + one-tap import is cut. Con: subjective, easy to rationalize a pet feature back in without a written rule.

Best practice / pitfall: keep Must-haves genuinely small — a focused MVP is ~3–7 features, and overloading "Must" dilutes the whole exercise. The real value of the framework is the **Won't-have list**: it makes exclusions visible so "what about X?" gets answered with "that's v2," not a code change. ([Won't-have prevents creep](https://www.mvpexpert.com/blog/rice-vs-moscow-the-ultimate-2025-guide-to-mvp-feature-prioritization-frameworks), [ministryofprogramming](https://ministryofprogramming.com/blog/how-to-identify-and-prioritize-core-mvp-features-in-2025))

**Recommendation:** MoSCoW, but spend most of the effort on the Won't-have column. Your Must list is effectively already fixed by the release criteria (note CRUD, editor, 3 import adapters, AI chat, Drive sync, Khmer/English parity). So the productive 20 minutes is writing the **explicit non-goals** — e.g. no new import sources beyond the three, no collaborative/multi-device real-time, no web app, no AI provider swaps, no new editor block types, no theming work beyond what ships. This matches the roadmap's own "Hold the line on non-goals" risk and gives you a document to point at all week.

### Sub-step 2 — Record and publish the freeze so it's a reference, not a memory

Options:

- **Add it to the Notion "Trovara Launch" page** (a "Frozen scope / Non-goals" callout under Release criteria). Pro: same place the phase checklist already lives; easy to re-read each morning. Con: separate from the code.
- **Put it in `ROADMAP.md` / a `docs/` note in the repo.** Pro: a markdown checklist in the repo "keeps you honest about scope" and sits next to your Autonomous Execution Protocol, which already reads ROADMAP.md first. Con: less visible than Notion for non-coding moments. ([solo-dev scope-in-repo](https://levelup.gitconnected.com/a-practical-ios-app-launch-checklist-for-indie-developers-2025-edition-53f0265af6f8))
- **Both — Notion is the announcement, repo is the source of truth.** Pro: covers planning and coding contexts. Con: two places to keep in sync (minor at this scale).

Best practice / pitfall: a feature freeze only works with a stable, written cutoff — an unwritten freeze isn't a freeze. Timebox it too: a freeze that drags invites stagnation, one too short skips stabilization; a 3–7 day window is about right. ([feature-freeze balance](https://ones.com/blog/mastering-feature-freeze-software-development/))

**Recommendation:** Write it once in `ROADMAP.md` under a `## Frozen scope (as of 2026-07-11)` heading with the Must list and the Non-goals list, then paste the same block into a Notion callout and check the Day 1 box. The repo copy is authoritative because your own protocol already treats ROADMAP.md as the entry point each session.

### Sub-step 3 — Set up mid-sprint change control so the freeze holds

Options:

- **Parking-lot list ("v2 / later").** Pro: dead simple — new ideas get written down and deferred without derailing the day; low ceremony for a solo dev. Con: only works if you actually triage it after launch, not during. ([parking lot in scrum](https://www.dartai.com/blog/what-is-parking-lot-in-scrum))
- **Log every idea as a Linear issue labeled `post-launch`.** Pro: you already use Linear (HUL-14, your protocol archives plans there); keeps everything in one tracker. Con: slightly more friction than a text file mid-flow.
- **Bug-vs-feature triage rule.** Pro: the highest-leverage rule during a freeze is distinguishing a genuine bug fix (allowed) from a feature in disguise (deferred); guards the freeze without blocking real fixes. Con: requires honest self-discipline — the failure mode for solo devs is calling a new feature a "fix." ([distinguish fixes from features](https://ones.com/blog/mastering-feature-freeze-software-development/), [change during a sprint](https://learn.microsoft.com/en-us/azure/devops/cross-service/manage-change?view=azure-devops))

Best practice / pitfall: during a freeze, only accept changes that are small and don't violate the release goal; everything else becomes a backlog item for after ship. The classic trap is "scope kills more solo projects than skill does" — creep arrives disguised as tiny improvements. ([scope creep in solo/indie](https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell))

**Recommendation:** One rule + one bucket. Rule: *only bug fixes and store-blocking issues touch code before launch; everything else is `post-launch`.* Bucket: a `post-launch` label in Linear (you're already there) or a "v2" section at the bottom of ROADMAP.md. When an idea shows up mid-week, log it in 10 seconds and move on. This directly serves the solo-dev + tight-window context: your scarce resource is focus, not ideas.

---

## Decisions to make

- [ ] **Prioritization method:** confirm MoSCoW-lite (Must list is fixed by release criteria; effort goes into the Non-goals column). 
- [ ] **Write the Non-goals list:** lock the explicit "Won't-have for v1" (suggested: no 4th import source, no real-time multi-device, no web app, no AI-provider swap, no new editor blocks, no extra theming).
- [ ] **Where the freeze lives:** ROADMAP.md as source of truth + Notion callout as the visible announcement (recommended), or one of the two.
- [ ] **Freeze window:** confirm the 3–7 day timebox and a hard "no new features after today" line.
- [ ] **Change-control rule:** adopt "only bug fixes / store-blockers touch code; all else → `post-launch`."
- [ ] **Where deferred ideas go:** Linear `post-launch` label vs. a ROADMAP.md "v2" section (pick one bucket).
- [ ] Then check the Day 1 **"Lock feature set (freeze scope)"** box and start Day 2 QA.

---

### Sources
- [Mastering Feature Freeze — ones.com](https://ones.com/blog/mastering-feature-freeze-software-development/)
- [RICE vs MoSCoW (2026) — mvpexpert.com](https://www.mvpexpert.com/blog/rice-vs-moscow-the-ultimate-2025-guide-to-mvp-feature-prioritization-frameworks)
- [MoSCoW for MVP Features — tekxai.com](https://tekxai.com/moscow-method-for-mvp-features/)
- [MoSCoW Prioritization — Product School](https://productschool.com/blog/product-strategy/moscow-prioritization)
- [Identify & prioritize core MVP features 2025 — ministryofprogramming.com](https://ministryofprogramming.com/blog/how-to-identify-and-prioritize-core-mvp-features-in-2025)
- [Practical iOS App Launch Checklist for Indie Devs (2025) — Level Up Coding](https://levelup.gitconnected.com/a-practical-ios-app-launch-checklist-for-indie-developers-2025-edition-53f0265af6f8)
- [Scope Creep in Indie Games — Wayline](https://www.wayline.io/blog/scope-creep-indie-games-avoiding-development-hell)
- [What is a Parking Lot in Scrum — dartai.com](https://www.dartai.com/blog/what-is-parking-lot-in-scrum)
- [Manage Change in Agile Projects — Microsoft Learn](https://learn.microsoft.com/en-us/azure/devops/cross-service/manage-change?view=azure-devops)
- [Flutter MVP Launch Checklist — flutteragency.com](https://flutteragency.com/blogs/flutter-mvp-launch-checklist/)

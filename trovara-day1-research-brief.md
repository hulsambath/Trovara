# Trovara Research Brief — **Day 1: Stabilize** · 2026-07-10

This brief covers **Day 1 — Stabilize**, the earliest phase in the "Trovara Launch" Notion page with unchecked to-dos (every Day 1 item is still open). Four tasks: triage/fix P0–P1 crashers, get `flutter analyze` clean, get `flutter test patrol_test` green, and lock scope. For each I've broken the work into concrete sub-steps with 2–3 options, a pitfall note, and a recommendation tuned to Trovara's local-first + Khmer + solo-dev reality.

**How to use this:** Day 1 is a gate, not a feature day. The goal is a green build you trust, not new capability. Bias every choice toward "fast, low-setup, reversible." The Decisions checklist at the end summarizes the open calls.

---

## Task 1 — Triage bug list; fix all P0/P1 crashers

### Sub-step 1a — Capture crashes with real stack traces (not memory)
You can't triage what you can't see. Before ranking bugs, make sure crashes on your test devices produce symbolicated stack traces, especially from the obfuscated prod-release build you'll cut on Day 4.

- **Firebase Crashlytics** — Pro: free, first-class Flutter plugin, groups similar crashes by stack trace automatically, and you already use Firebase (flavor-specific `firebase_options`). Con: async/isolate errors and Dart-layer context are thinner than Sentry's. ([Sentry vs Crashlytics](https://pro.codewithandrea.com/flutter-in-production/04-error-monitoring/02-sentry-vs-crashlytics))
- **Sentry** — Pro: captures exceptions, log messages and performance, deobfuscates minified Dart, richer breadcrumbs. Con: another SDK/account to wire up mid-sprint; more than a solo launch needs on Day 1. ([Sentry for Flutter](https://sentry.io/from/crashlytics/))
- **Local `FlutterError.onError` + `runZonedGuarded` logging** — Pro: zero new dependency, uses your existing `logger`; instant. Con: no aggregation, no remote visibility once real users hit it. ([Flutter Gems: crash insights](https://fluttergems.dev/performance-crash-insights/))

**Pitfall:** obfuscated release builds produce useless stack traces unless you upload debug symbols. Whatever tool you pick, verify a deliberately-thrown test crash shows a readable trace *from the release flavor* before you rely on it.

**Recommendation:** **Crashlytics.** It's explicitly the fit for "hobbyists, solopreneurs, and small teams," it's already in your Firebase setup, and its auto-grouping is exactly what triage needs. Keep the local `runZonedGuarded` handler too — it costs nothing and helps on-device debugging today. Defer Sentry unless post-launch error volume demands deeper Dart context.

### Sub-step 1b — Rank each bug by Severity × Priority
Separate "how bad when it happens" (severity) from "how urgently must I fix it" (priority). A crash nobody hits is high severity, low priority; a broken import on the happy path is both.

- **P0/P1/P2 label scheme (Flutter's own model)** — Pro: battle-tested; P0 = "stop the presses"/build break/crash-on-core-flow, P1 = major feature broken for most users, P2 = significant subset. Maps cleanly to your release criteria. Con: needs discipline to apply consistently solo. ([Flutter Triage wiki](https://github.com/flutter/flutter/wiki/Triage/7b1f72bc7f85c9a2bcadaad0034cb7ed56f23718))
- **Severity-vs-Priority 2×2** — Pro: forces the "high-severity / low-priority" distinction so you don't burn Day 1 on rare crashes. Con: slightly more overhead per bug. ([Bug severity vs priority](https://plane.so/blog/bug-severity-vs-priority-in-testing-key-differences))
- **Necessity × Effort matrix** — Pro: great for deciding *order* — fix high-necessity/low-effort first. Con: it's a scoping lens, better for Task 4 than crash triage. ([Prioritizing bugs](https://plane.so/blog/bug-triage-process-how-to-run-it-and-what-to-prioritize))

**Pitfall:** open P0/P1 bugs are release blockers by definition — don't let a P1 quietly slide to "later." If it's P0/P1, it goes in today's work or the launch slips.

**Recommendation:** Use **Flutter's P0/P1/P2 labels** as the spine, anchored to your five critical flows (note CRUD, editor, imports, AI chat, Drive sync). Rule of thumb: any crash or data-loss on those five = **P0**; broken-but-recoverable behavior on them = **P1**; everything else = **P2/backlog** and explicitly out of Day 1.

### Sub-step 1c — Fix, then guard against regression
For each P0/P1: reproduce → fix → add the thinnest possible test so it can't silently return.

- **Patrol logic test in `patrol_test/`** — Pro: runs without an emulator (`flutter test patrol_test`), matches your existing harness, ties directly into Task 3's green bar. Con: only covers logic-reachable paths, not native-layer crashes.
- **Manual re-verify on device + note in ROADMAP** — Pro: fastest for native/rendering crashes; fits Khmer on-device checks. Con: no automated safety net; relies on you remembering.
- **Crashlytics velocity alert as the net** — Pro: catches what tests miss once shipped. Con: reactive — user already hit it.

**Recommendation:** For any P0/P1 whose root cause is in Dart/logic, write a one-line **patrol_test** reproduction before fixing (red → green). For native/rendering crashes, re-verify on-device and log it. This directly advances Task 3 instead of competing with it.

---

## Task 2 — Get `flutter analyze` clean

### Sub-step 2a — Auto-fix the mechanical majority first
Most analyzer noise (missing `const`, unused imports, single-quote prefs) is machine-fixable. Clear it before touching anything by hand.

- **`dart fix --dry-run` then `dart fix --apply`** — Pro: resolves mechanical lints across the whole repo in seconds; `--dry-run` previews so nothing surprises you. Con: only fixes rules with associated quick-fixes; won't touch logic issues. ([dart fix docs](https://dart.dev/tools/dart-fix))
- **IDE quick-fixes one by one** — Pro: full control, good for ambiguous cases. Con: painfully slow across a whole codebase. ([Dart analyzer commands](https://medium.com/@arunb9525/mastering-dart-analyzer-essential-commands-for-clean-and-reliable-code-bda7265883f0))
- **`dart format` pass alongside** — Pro: kills the 120-char / formatting diffs your analyzer flags. Con: large reformat diffs can bury real fixes in git — commit separately.

**Pitfall:** run `dart fix --apply` as its **own commit** with tests green on both sides, so a bad auto-edit is easy to bisect. Your CLAUDE.md forbids editing generated `*.g.dart` — `dart fix` respects analyzer excludes, but confirm they're excluded in `analysis_options.yaml`.

**Recommendation:** `dart fix --dry-run` → eyeball → `dart fix --apply` → `dart format` → commit as `style(core): dart fix + format`. Then re-run `flutter analyze` to see what's genuinely left.

### Sub-step 2b — Resolve the remaining hand-fix warnings without weakening rules
Whatever survives auto-fix is real. Fix the code, don't silence the linter.

- **Fix at the source** — Pro: keeps your strict rules (single quotes, const-everywhere, `avoid_print`) meaningful. Con: slowest, but these are the ones that catch bugs.
- **Targeted `// ignore:` with a reason** — Pro: legitimate for rare false positives. Con: every ignore is future debt; easy to overuse under deadline. ([DCM lints guide](https://dcm.dev/blog/2025/10/21/getting-started-flutter-static-analytics-lints/))
- **Loosen a rule in `analysis_options.yaml`** — Pro: instant zero-warning. Con: defeats the purpose and violates your own non-negotiables — avoid on Day 1.

**Recommendation:** **Fix at the source.** Reserve `// ignore:` for documented false positives only, with a trailing comment. Do **not** relax analysis_options to hit a clean bar — that trades a real Day 1 gate for a fake one. `avoid_print` violations → route to your `logger`, per house rules.

### Sub-step 2c — Keep it clean for the rest of the sprint
Clean once is worth little if Day 2–4 edits reintroduce warnings.

- **Pre-commit hook running `flutter analyze`** — Pro: you already ship `./scripts/install_hooks.sh`; makes clean the default. Con: slight commit latency.
- **The Stop hook / `/build-and-test` command** — Pro: your Definition of Done already enforces analyze-clean; lean on it. Con: later in the loop than a pre-commit.

**Recommendation:** Ensure the **pre-commit hook** is installed now so every Day 2+ commit stays clean; treat `flutter analyze` = 0 as the non-negotiable it already is in your Definition of Done.

---

## Task 3 — Get `flutter test patrol_test` green

### Sub-step 3a — Get an honest baseline
Run the suite and separate real failures from flakes before fixing anything.

- **Run `flutter test patrol_test` 3× and diff** — Pro: exposes non-deterministic tests immediately; no tooling. Con: manual.
- **Run per-file** (`flutter test patrol_test/path/to/test.dart`) — Pro: isolates a failing area fast, matches how your docs invoke it. Con: misses cross-test state bleed.

**Pitfall:** Patrol is known to be flaky on CI because it synchronizes Flutter and native layers; timing differs from local machines. Your `patrol_test/` uses `patrolWidgetTest` (no emulator), which sidesteps most of that — but don't assume a local pass means CI pass. ([Patrol on CI](https://patrol.leancode.co/), [Flutter testing strategy](https://medium.com/@m.m.shahmeh/flutter-testing-strategy-at-scale-af1aa236958e))

**Recommendation:** Run the suite **3 times**. Bucket failures into "consistently red" (real bug — feeds Task 1) vs "sometimes red" (flake — fix in 3b). Fix real failures first.

### Sub-step 3b — De-flake the intermittent tests
Flakes erode trust in the green bar. Fix the test design, don't just re-run.

- **Target stable identifiers (ValueKey / semantic labels)** — Pro: kills the most common flake source — matching on text that moves or localizes. Critical for you: Khmer/English strings shift, so never assert on visible `tr()` text. Con: requires adding keys to widgets. ([Patrol best practices](https://dev.to/hiteshm_devapp/patrol-the-flutter-testing-framework-that-changes-everything-3nb6))
- **Explicit `pumpAndSettle` / await-for-element** — Pro: removes animation/async races. Con: over-using `pumpAndSettle` can hang on infinite animations.
- **Retry annotation as a stopgap** — Pro: unblocks a green bar today. Con: hides the flake; a crutch, not a fix.

**Pitfall:** asserting on localized strings is a double trap for Trovara — a test that passes in English silently breaks under Khmer. Assert on keys, not rendered text.

**Recommendation:** Add **ValueKeys/semantic labels** to the widgets your critical-flow tests touch and match on those; add explicit awaits where animations race. Use retries only as a temporary unblock with a ROADMAP note to fix properly.

### Sub-step 3c — Cover the five critical flows, and no more (today)
Day 1 is about a trustworthy gate, not coverage maximalism.

- **Happy-path-only for the five flows** — Pro: highest confidence per minute; matches launch criteria exactly. Con: edge cases uncovered (acceptable Day 1).
- **Broaden to edge cases now** — Pro: more robust. Con: scope creep into Task 4 territory; not a Day 1 job.

**Recommendation:** Ensure a **green happy-path patrol_test exists for each of the five flows**. Log deeper cases in ROADMAP for post-launch. Green + trustworthy beats broad + flaky.

---

## Task 4 — Lock feature set (freeze scope)

### Sub-step 4a — Draw the freeze line explicitly
Write down what ships and what doesn't, so "just one more thing" has something to bounce off.

- **In / Out / Deferred list in ROADMAP.md** — Pro: single source of truth you already read every session per your protocol; zero new tooling. Con: only works if you honor it.
- **Necessity × Effort matrix to draw the line** — Pro: objective cut — ship high-necessity/low-effort, defer the rest. Con: a few minutes of upfront sorting. ([MVP scope framework](https://www.weweb.io/blog/mvp-development-complete-guide-from-idea-to-launch))

**Pitfall:** "silent scope creep" — small additions that each seem trivial but collectively sink the timeline. A written freeze line is the antidote. ([Solo-founder scope](https://dev.to/truongpx396/the-solo-founder-playbook-zero-hero-3j7d))

**Recommendation:** Add a **"Scope Freeze — Launch v1"** block to ROADMAP.md with In / Out / Deferred columns. "In" = the five critical flows + Khmer/English + the three importers already built. Everything else → Deferred. This is also your defense for the "hold the line on non-goals" risk already listed on the Notion page.

### Sub-step 4b — Convert every new idea into a post-launch backlog item
The freeze only holds if new ideas have a home that isn't "the launch build."

- **Deferred section in ROADMAP** — Pro: keeps ideas without acting on them; frictionless. Con: needs review discipline later.
- **Archive to Linear** — Pro: your autonomous protocol already archives plans to Linear; consistent home for backlog. Con: **Linear MCP currently needs re-authorization (unavailable this run)** — see note below.

**Recommendation:** Park new ideas in a **ROADMAP "Deferred / Post-launch" list** now; migrate to Linear when it's reconnected. The rule to internalize: nothing enters the launch build after freeze unless it's a P0/P1 fix.

### Sub-step 4c — Bind the freeze to your release criteria
Scope is truly locked when "done" is defined by the existing release-criteria checklist, not by feeling finished.

**Recommendation:** Treat the Notion **Release criteria** (analyze clean + patrol green, five flows verified on-device, Khmer/English parity, clean prod-release cold start, store assets) as the literal definition of "shippable v1." Freeze = no work that isn't either a release-criteria item or a P0/P1 fix.

---

## Decisions to make

- [ ] **Crash tooling:** Adopt **Crashlytics** for Day 1 (recommended), or invest in Sentry now for richer Dart context?
- [ ] **Triage scheme:** Confirm **P0 = crash/data-loss on the five critical flows**, P1 = broken-but-recoverable on them, everything else deferred?
- [ ] **Regression tests:** Commit to writing a **patrol_test reproduction** for every logic-layer P0/P1 before fixing?
- [ ] **Analyze clean-up:** Run **`dart fix --apply` + `dart format` as a standalone commit**, then hand-fix the rest — and refuse to loosen `analysis_options.yaml` to fake a clean bar?
- [ ] **Pre-commit hook:** Confirm `./scripts/install_hooks.sh` is installed so the build stays analyze-clean through Day 2+?
- [ ] **Flake policy:** Standardize on **ValueKeys/semantic labels + assert-on-keys-not-localized-text** (critical for Khmer)? Retries only as flagged stopgaps?
- [ ] **Test scope:** Accept **happy-path-only coverage of the five flows** as the Day 1 bar, deferring edge cases?
- [ ] **Scope freeze:** Add a written **"Scope Freeze — Launch v1" (In/Out/Deferred)** block to ROADMAP.md today and route all new ideas to Deferred?

---

### Notes & caveats
- **Linear MCP is not authorized this run**, so I could not archive backlog items there; your autonomous protocol's "archive plan to Linear" step will need it reconnected via connector settings. I've recommended ROADMAP.md as the interim home.
- Notion page was read successfully (snapshot 2026-07-05); **all Day 1 items were unchecked**, confirming Day 1 as the active phase.
- Sources are linked inline throughout.

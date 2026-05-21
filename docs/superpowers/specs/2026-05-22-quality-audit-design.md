# Quality Audit System — Design Spec

**Date:** 2026-05-22
**Author:** Sambath HUL (with Claude)
**Status:** Draft, pending user review

## 1. Purpose

Trovara has grown to 179 Dart files across notes, RAG, chat, sync, and import features, with only 23 test files. Recent merges (chat-source-service, multi-turn chat memory, RAG upgrades, Firebase AI migration) have added surface area faster than tests and architectural review can keep up.

This spec defines a **quality audit system** that:
1. Runs a one-shot multi-dimensional audit of the current codebase, producing a ranked punch list of findings.
2. Promotes the most-reusable audit dimensions into recurring slash commands so drift can be caught on every PR/release cycle going forward.

The system is read-only during the audit pass. All fixes are gated by user approval of a remediation plan and ship as separate PR batches.

## 2. Scope

The audit covers **eight dimensions**:

| # | Dimension | Examples in Trovara context |
|---|---|---|
| 1 | Security & data integrity | API key extraction from APK, Drive OAuth scopes, prompt injection via imported notes, ownership checks post anonymous→user-id migration |
| 2 | Bugs, crashes & exception safety | Unawaited futures, swallowed exceptions, race conditions in `google_drive_sync_service` / `chat_drive_sync_service`, null-bang misuse |
| 3 | Test coverage gaps | Untested critical paths (RAG pipeline, sync, import adapters, `ChatSourceService`); ranked "write these next" list |
| 4 | Architecture & code health | MVVM violations, ServiceLocator bypasses, files >300 LOC (6 known: `rag_service.dart` 681, `llm_client.dart` 667, `search_content.dart` 875, `note_view_model.dart` 534, `unified_tags_icon_button.dart` 580, `custom_tags_widget.dart` 513), hardcoded strings/colors/Material icons |
| 5 | Performance & dependencies | Embedding/vector hotspots, large-note rendering, ObjectBox query patterns, `flutter pub outdated` + CVE check |
| 6 | Fraud / abuse vectors | Unbounded API calls, anonymous→user-id takeover, content abuse via imported notes, cross-user data exfiltration through embeddings or shared Drive folders |
| 7 | Bias | RAG retrieval bias (recency/length/language), LLM output skew, Insights sentiment chart bias, UX default nudges |
| 8 | Negative correlation | Feature interactions that fight each other (cache vs. edits, sync vs. local changes, trash restore vs. embeddings), quality/cost trade-offs, Insights chart correlation math correctness |

**Out of scope:**
- Automated fixes during the audit pass. All 8 agents are read-only.
- CI integration. Slash commands run in local Claude Code sessions only.
- Threat modeling as a separate phase. We go wide and let the security-auditor surface what's present.
- Refactor to external tracker (Linear / GitHub Issues). The remediation plan + per-batch PRs are the tracking system.

## 3. Architecture

```
                         ┌──────────────────────────┐
                         │  /audit  (orchestrator)  │
                         └────────────┬─────────────┘
                                      │ dispatch 8 in parallel
       ┌──────────────┬───────────────┼───────────────┬──────────────┐
       ▼              ▼               ▼               ▼              ▼
 [security]    [bugs+crashes]    [test-gaps]   [architecture]   [perf+deps]
       │              │               │               │              │
       └──────┬───────┴──────┬────────┴───────┬───────┴──────┬───────┘
              ▼              ▼                ▼              ▼
          [fraud]         [bias]      [neg-correlation]      (+aggregator)
                                            │
                                            ▼
                          ┌──────────────────────────────┐
                          │  Aggregator (main loop)      │
                          │  - dedup cross-cutting       │
                          │  - rank by severity × effort │
                          │  - emit single report.md     │
                          └──────────────┬───────────────┘
                                         ▼
                ┌────────────────────────────────────────┐
                │ docs/superpowers/audits/YYYY-MM-DD/    │
                │   ├─ 00_report.md  (ranked punch list) │
                │   ├─ 01_security.md                    │
                │   ├─ 02_bugs.md     … etc              │
                │   └─ 09_remediation_plan.md            │
                └────────────────────────────────────────┘
```

### 3.1 The 8 auditor agents

Each agent runs as a Claude Code sub-agent. Each receives a focused prompt, scope description, and pointers to relevant `CLAUDE.md` files. Each must return findings in a fixed contract (see §3.2).

| # | Agent | Sub-agent type | Scope |
|---|---|---|---|
| 1 | `security-auditor` | Explore | Secrets in code / extractable from APK, OAuth scope width, ownership checks, input boundaries flowing into LLM/ObjectBox |
| 2 | `bugs-crashes-auditor` | Explore | Exception swallowing, unawaited futures, null-bang on nullables, stream subs never cancelled, sync races |
| 3 | `test-gaps-auditor` | general-purpose (needs Bash for `find` counts) | Map every service/ViewModel/repo without a `patrol_test/` file; rank gaps by criticality |
| 4 | `architecture-auditor` | Explore | MVVM/ServiceLocator/style-guide violations; uses existing `style-reviewer` patterns |
| 5 | `perf-deps-auditor` | general-purpose (needs Bash for `flutter pub outdated`) | Hotspots + supply chain |
| 6 | `fraud-auditor` | Explore | Abuse vectors per §2 row 6 |
| 7 | `bias-auditor` | Explore | RAG/LLM/UX bias per §2 row 7 |
| 8 | `neg-correlation-auditor` | Explore | Feature interaction conflicts per §2 row 8 |

### 3.2 Output contract

Every agent returns a markdown table:

```
| Severity | Category | File:Line | Finding | Recommendation | Effort |
```

- **Severity:** `Critical` (data loss / security breach) · `High` (crash / wrong-result) · `Medium` (degraded UX / tech debt with blast radius) · `Low` (style / nit)
- **Effort:** `S` (<1h) · `M` (1–4h) · `L` (>4h or design needed)
- **File:Line:** Required when finding maps to a specific location. For interpretive findings (bias, neg-correlation), agents emit `N/A` — these get a separate "Conceptual findings" section in `00_report.md`.

### 3.3 Aggregation pipeline

After all 8 agents return, the orchestrator (main loop) runs:

1. **Normalize** — parse tables into a flat list of finding objects.
2. **Dedup** — key by `(file, line ±3 lines)`. On collision: keep higher severity, merge `category` and `recommendation`, list all source agents.
3. **Rank** — sort by severity weight first, then by an ROI score computed as `severity_weight` divided by `effort_weight`.

   | Severity | Weight | | Effort | Weight |
   |---|---|---|---|---|
   | Critical | 8 | | S | 1 |
   | High | 4 | | M | 3 |
   | Medium | 2 | | L | 8 |
   | Low | 1 | | | |

   A `Critical/S` (8.0) ranks above `Critical/M` (2.67), which ranks above `High/S` (4.0).

4. **Emit** — write `00_report.md` (exec summary + top-10 + full ranked table) and `09_remediation_plan.md` (proposed PR batches).

### 3.4 Reusable command promotion

After the one-shot pass, four agents graduate to slash commands. The other four remain inline-only in the orchestrator.

| Command | Wraps | Why promote |
|---|---|---|
| `/audit-security` | `security-auditor` | Highest stakes; invalidated by every code change. Run before each release. |
| `/audit-coverage` | `test-gaps-auditor` | Cheap, directly actionable. Run after each feature merge. |
| `/audit-architecture` | `architecture-auditor` | Catches MVVM/style drift; complements `style-reviewer`. Run before PR. |
| `/audit-deps` | perf-deps-auditor (deps half) | Re-runs `flutter pub outdated` + CVE check. Run monthly. |

**Not promoted (and why):**
- `bugs-crashes-auditor` — overlaps `flutter analyze` (already in Definition of Done) and `/audit-coverage`. Re-running adds noise.
- `fraud-auditor` — findings are largely architectural; once fixed, don't regress per-commit. Re-run after major auth/RAG changes.
- `bias-auditor`, `neg-correlation-auditor` — interpretive, need human judgment per finding. Better as quarterly deep-dives.
- The **perf half** of agent 5 — hotspots don't drift weekly; benefits from focused investigation.

### 3.5 Orchestrator behavior

`.claude/commands/audit.md` (currently a stub in the repo) is rewritten:

- **Default mode** — runs the 4 promoted commands in parallel, aggregates into a fresh dated folder under `docs/superpowers/audits/YYYY-MM-DD/`.
- **`--full` flag** — also dispatches the 4 one-shot agents (bugs, fraud, bias, neg-correlation). Use quarterly or pre-release.
- **`--only <name>` flag** — runs a single sub-command (e.g., `/audit --only security`).

All four promoted commands write to the same dated folder, append-only. Re-running `/audit-security` weekly produces a history (`2026-05-22/01_security.md`, `2026-05-29/01_security.md`) for trend tracking.

## 4. Deliverables

### 4.1 Audit run output (per execution)

```
docs/superpowers/audits/2026-05-22/
  ├─ 00_report.md              ← ranked punch list + exec summary
  ├─ 01_security.md
  ├─ 02_bugs.md
  ├─ 03_test_gaps.md
  ├─ 04_architecture.md
  ├─ 05_perf_deps.md
  ├─ 06_fraud.md
  ├─ 07_bias.md
  ├─ 08_neg_correlation.md
  └─ 09_remediation_plan.md
```

### 4.2 Reusable infrastructure (committed once)

```
.claude/commands/
  ├─ audit.md                  ← orchestrator (rewritten from stub)
  ├─ audit-security.md
  ├─ audit-coverage.md
  ├─ audit-architecture.md
  └─ audit-deps.md

.claude/agents/
  ├─ security-auditor.md
  ├─ test-gaps-auditor.md
  ├─ architecture-auditor.md
  └─ deps-auditor.md
```

The 4 non-promoted agents (bugs, fraud, bias, neg-correlation) are defined as inline prompts inside `audit.md` — not as standalone `.claude/agents/` files, since they aren't meant to be invoked individually.

## 5. Workflow

1. **Spec approval** — this document. User reviews and approves.
2. **Implementation plan** — separate session via `superpowers:writing-plans`, produces step-by-step plan in `docs/superpowers/plans/2026-05-22-quality-audit.md`.
3. **Plan execution**, in order:
   1. Build 4 reusable subagent definitions in `.claude/agents/`.
   2. Build 4 slash commands wrapping them in `.claude/commands/`.
   3. Rewrite `.claude/commands/audit.md` as orchestrator with inline definitions for the 4 non-promoted agents.
   4. Run `/audit --full` → produces `2026-05-22/` audit folder.
   5. User reviews `00_report.md` and approves `09_remediation_plan.md`.
4. **Per-batch remediation** — each approved batch becomes one PR. Implement, review, merge.

### 5.1 Timing estimate

| Phase | Wall-clock |
|---|---|
| Build subagents + commands | ~30 min |
| Run `/audit --full` (8 agents in parallel) | ~10–15 min |
| Aggregation + report writing | ~5 min |
| User review of report | as needed |
| Remediation PRs | varies — Batch 1 (Critical/S) likely 1–2 days |

## 6. Open questions for spec review

1. **Issue tracker integration** — should `09_remediation_plan.md` open a GitHub issue per batch, or just a PR? *Default: PR-only, no issues.*
2. **`/audit-deps` write authority** — should it auto-run `flutter pub upgrade --major-versions` for non-CVE deps, or stay strictly read-only? *Default: strictly read-only.*

## 7. Definition of done for this audit system

The audit system is complete when:

1. All 4 reusable slash commands and 4 subagent definitions are committed.
2. `/audit.md` orchestrator is committed with inline definitions for the 4 non-promoted agents.
3. A first run of `/audit --full` has produced a complete `docs/superpowers/audits/2026-05-22/` folder.
4. The user has reviewed `00_report.md` and approved a remediation plan.
5. At least one remediation batch PR has been opened, demonstrating the end-to-end flow works.

Remediation of all findings is **not** required for the system itself to be "done" — that is ongoing work tracked by the per-batch PRs.

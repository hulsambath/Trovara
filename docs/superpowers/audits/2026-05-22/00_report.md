# Quality Audit Report — 2026-05-22

## Run status

**Partial run.** The 4 promoted dimensions completed; the 5 one-shot dimensions hit a session limit at 05:40 Asia/Phnom_Penh and are deferred. Re-run `/audit --full` after the reset to populate:

- `02_bugs.md` (bugs / crashes / races / leaks)
- `06_fraud.md` (API abuse / auth abuse / content abuse / exfiltration)
- `07_bias.md` (RAG / LLM / UX bias)
- `08_neg_correlation.md` (feature conflicts / quality-cost tradeoffs)
- Perf findings appendix in `05_perf_deps.md`

This report covers the four completed dimensions only: **security, test gaps, architecture, dependencies.**

## Summary

| Severity | Count |
|---|---|
| Critical | 7 |
| High | 17 |
| Medium | 16 |
| Low | 35 |
| **Total** | **75** |

All Critical findings are test-coverage gaps in repositories and sync services. All High findings are split between security/ownership (4), MVVM violations (5), and high-criticality test gaps (8).

## Top 10 by ROI

ROI score = `severity_weight / effort_weight`. Weights: Critical=8 · High=4 · Medium=2 · Low=1 ÷ S=1 · M=3 · L=8.

| Rank | Score | Severity | Effort | Category | File:Line | Finding |
|---|---|---|---|---|---|---|
| 1 | 8.0 | Critical | S | TestGap | lib/core/repository/implementations/objectbox_embedding_repository.dart:1 | No patrol_test coverage for embedding persistence mutations |
| 2 | 8.0 | Critical | S | TestGap | lib/core/repository/implementations/objectbox_chat_message_repository.dart:1 | No patrol_test coverage for chat message persistence |
| 3 | 8.0 | Critical | S | TestGap | lib/core/repository/implementations/objectbox_chat_thread_repository.dart:1 | No patrol_test coverage for chat thread lifecycle |
| 4 | 4.0 | High | S | MVVM | lib/views/search/search_content.dart:708 | View calls TextParserService directly |
| 5 | 4.0 | High | S | MVVM | lib/views/setting/setting_view_model.dart:222 | ViewModel uses Navigator.push instead of go_router |
| 6 | 4.0 | High | S | TestGap | lib/core/services/ai/multi_query_expansion_service.dart:1 | No coverage for LLM query expansion |
| 7 | 4.0 | High | S | TestGap | lib/core/services/ai/query_rewrite_service.dart:1 | No coverage for query rewriting |
| 8 | 4.0 | High | S | TestGap | lib/core/services/notes/text_parser_service.dart:1 | No coverage for tag/title parsing |
| 9 | 2.67 | Critical | M | TestGap | lib/core/repository/implementations/objectbox_note_repository.dart:1 | No coverage for note CRUD repository |
| 10 | 2.67 | Critical | M | TestGap | lib/core/services/sync/google_drive_sync_service.dart:1 | No coverage for Drive sync conflict logic |

## Notable security/ownership findings (High severity)

These don't all rank in the top 10 by ROI but are worth surfacing:

- **`lib/core/services/auth/google_drive_service.dart:83`** — Drive API cached forever with stale auth headers; subsequent calls silently use expired tokens until a 401 triggers a full interactive re-auth. (High/M, ROI 1.33)
- **`lib/core/repository/implementations/objectbox_note_repository.dart:117`** — `_userOwnershipCondition` matches `userId IS NULL`, so pre-login anonymous notes leak across Google accounts on shared devices. (High/M, ROI 1.33)
- **`lib/core/services/ai/vector_search_service.dart:67`** — `getAllEmbeddings()` returns embeddings for all users with no userId filter. RAG can leak content cross-account. (High/L, ROI 0.5)
- **`lib/core/repository/implementations/objectbox_chat_thread_repository.dart:38`** — Chat thread queries don't filter by userId; history visible across accounts. (High/L, ROI 0.5)

## Conceptual findings (no file:line)

None this run — deferred dimensions (bias, neg-correlation) typically produce these.

## Per-dimension drill-downs

- [Security](01_security.md) — 4 High, 5 Medium, 2 Low
- Bugs & crashes — **deferred** (`02_bugs.md` not generated)
- [Test gaps](03_test_gaps.md) — 7 Critical, 8 High, 2 Medium, 1 Low
- [Architecture](04_architecture.md) — 5 High MVVM, 8 Medium FileSize, 21 Low style
- [Perf & deps](05_perf_deps.md) — 13 Medium + 19 Low (deps half only; perf deferred)
- Fraud — **deferred** (`06_fraud.md` not generated)
- Bias — **deferred** (`07_bias.md` not generated)
- Negative correlation — **deferred** (`08_neg_correlation.md` not generated)

## Remediation plan

See [09_remediation_plan.md](09_remediation_plan.md).

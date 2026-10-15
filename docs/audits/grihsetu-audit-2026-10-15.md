# GrihSetu audit — 2026-10-15

## Scope and evidence

This audit covers GRIH-001 through GRIH-027 against the repository state on
2026-10-15. Evidence was taken from the checked-out source, tests, Firestore
rules/indexes/schema documentation, local Git history, and the available
GitHub pull-request search. The supplied `.xlsm` tracker workbook was not
present in the repository or the supplied attachments, so tracker cells were
not modified and tracker-specific status/date/owner claims remain
unverified.

The GitHub connector found PR records for #5, #6, #7, #9, #10, #11, #12, #14,
#15, #16, #17, #18, #19, #21, #23, #24, and #26. Local Git history confirms
the corresponding merged work is represented in the current `main` history.
The connector did not return complete state/date metadata, so this report does
not infer missing tracker values from search results.

Observed PR links: [#5](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/5),
[#6](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/6),
[#7](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/7),
[#9](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/9),
[#10](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/10),
[#11](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/11),
[#12](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/12),
[#14](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/14),
[#15](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/15),
[#16](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/16),
[#17](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/17),
[#18](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/18),
[#19](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/19),
[#21](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/21),
[#23](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/23),
[#24](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/24), and
[#26](https://github.com/kalviumcommunity/sw2627-grihsetu-kalviumcommunity/pull/26).

## Executive summary

- 27 backlog items audited; no item was found to be wholly absent from the
  codebase.
- 20 items are verified complete from repository evidence.
- 6 items are complete after the implementation/audit fixes in this pass.
- 1 item remains partially evidenced because approved UX/mockup and tracker
  evidence is not available in the workspace.
- GRIH-025 is implemented end-to-end for the client/service layer: authoritative
  visit history, transaction-safe numbering, idempotent starts, completion and
  follow-up handling, repeat detection, detail/technician history UI, rules,
  schema documentation, and regression tests.
- Firebase Emulator concurrency/security verification, a physical-device pass,
  and any production legacy migration were not executed in this workspace.

## Backlog matrix

| ID | Status | Repository evidence / remaining qualification |
|---|---|---|
| GRIH-001 | Verified Complete | PRD exists and is now linked from README; roles, lifecycle, priorities, and MVP scope are documented. |
| GRIH-002 | Partially Complete | UX documentation and implemented screens exist; approved mockup/tracker evidence was not supplied. |
| GRIH-003 | Verified Complete | README documents product purpose, stack, structure, setup, and contribution context. |
| GRIH-004 | Verified Complete | Flutter/Firebase configuration, platform setup, rules, indexes, and automated validation are present. Device/manual release validation remains external. |
| GRIH-005 | Verified Complete | Theme, navigation shell, role-aware entry flow, and feature screens are implemented. |
| GRIH-006 | Verified Complete | Complaint/visit models and enums exist; repeat state is now derived from the authoritative count. |
| GRIH-007 | Verified Complete | Firebase auth/profile services, role gating, and tests exist. |
| GRIH-008 | Verified Complete | Complaint creation, validation, persistence, and tests exist. |
| GRIH-009 | Verified Complete | Authentication gate and protected routing are implemented and tested. |
| GRIH-010 | Verified Complete | Firestore schema, repositories, rules, indexes, and repository tests exist. |
| GRIH-011 | Verified Complete | Property/unit selection flow and tests exist. |
| GRIH-012 | Verified Complete | Seed/demo data service and deterministic tests exist; production seed execution was not run. |
| GRIH-013 | Verified Complete | Atomic complaint creation and audit-event write path is implemented and tested. |
| GRIH-014 | Verified Complete | Complaint form fields, validation, and workflow tests exist. |
| GRIH-015 | Verified Complete | Complaint list stream/query and tests exist. |
| GRIH-016 | Verified Complete | Assignment/reassignment service, history, and transaction tests exist. |
| GRIH-017 | Verified Complete | Assignment UI and state transitions are implemented and tested. |
| GRIH-018 | Verified Complete | Technician queue, active-status filtering, rules, index, and tests exist. |
| GRIH-019 | Verified Complete | Centralized append-only audit writer, repository reads, rules, and tests exist. |
| GRIH-020 | Complete After Fix | Detail/timeline now consumes actual maintenance visits when available, with safe audit fallback and stable rendering. |
| GRIH-021 | Verified Complete | Shared UI widgets and regression coverage exist. |
| GRIH-022 | Complete After Fix | Atomic visit start, count/flag invariant, duplicate guard, deterministic numbering, and malformed-history reconciliation are covered. Emulator concurrency is still required for final release evidence. |
| GRIH-023 | Complete After Fix | Visit workflow UI now reads stored visit history and preserves first/second/third visit semantics. |
| GRIH-024 | Verified Complete | Current Git history contains the merged implementation and automated coverage. |
| GRIH-025 | Complete After Fix | Full implementation is described below; emulator/device/production migration evidence remains external. |
| GRIH-026 | Complete After Fix | Previous visits are sourced from `maintenance_visits` with audit fallback and explicit visit numbering. |
| GRIH-027 | Complete After Fix | History timestamps and nullable legacy values render safely in complaint and technician views. |

## GRIH-025 implementation detail

### Data model and invariants

`maintenance_visits/{visitId}` is the source of truth for visit history.
Every successful start creates exactly one record and one sequence number.
Completion and follow-up operations update that record and do not increment
`complaints.visitCount` again. The complaint stores the transaction lock and
the current `activeVisitId`; `isRepeatVisit` is derived from
`visitCount > 1`, including when old persisted flags are stale.

### Start, completion, and idempotency

Start uses a transaction on the complaint document, verifies assignment and
active-visit state, checks a supplied `operationId`, allocates the next number,
creates the visit, and updates the complaint count/flag/active ID together.
The in-memory adapter mirrors the same first/second/third-visit behavior for
deterministic tests. Completion requires the active visit in Firestore, updates
the visit and complaint status atomically, and leaves the count unchanged.
Follow-up records are retained and do not cause an accidental extra count.

### History and UI

Complaint detail and technician visit screens subscribe to the stored visit
history, show visit number, technician, timestamps, observation/action,
outcome, resolution, and follow-up notes, and retain a safe audit-event
fallback for legacy records. The first visit is not marked as a repeat; visits
2 and later are.

### Legacy reconciliation

`MaintenanceVisitReconciliation` is deliberately read-only. It identifies
stale count/flag values, duplicate or gapped numbering, and the derived next
number without modifying records. No automatic production migration was
executed. Records with malformed historical numbering are rejected by the new
start path rather than silently renumbered.

## Validation

Passed:

- `flutter analyze` — exit 0; 22 existing info-level lint notices, no errors
  or warnings introduced by this work.
- `flutter test test/maintenance_visit_reconciliation_test.dart test/in_memory_visit_history_test.dart test/maintenance_visit_test.dart test/visit_workflow_test.dart` — all tests passed.
- `flutter test test/complaint_detail_test.dart test/technician_queue_screen_test.dart` — all tests passed after regression fixes.
- `flutter test` — passed, 234 tests.
- `flutter pub get` — passed; dependency lockfile resolved with 10 packages
  having newer versions outside the current constraints.
- Targeted Dart formatting check and `git diff --check` — passed.

Not run / not available:

- Firebase Emulator concurrency and Firestore-rules integration tests.
- Physical Android/iOS device validation.
- Production Firestore writes or legacy-data migration.
- The requested `.xlsm` tracker workbook was not available.

## Handoff and release risks

The working tree contains the implementation and documentation changes; no
production data was changed. Before merging, run the Firebase Emulator tests
for concurrent starts, duplicate `operationId`, unauthorized visit reads and
writes, assignment changes during a start, and malformed legacy histories.
The normal branch convention in this checkout is `main`; create the requested
`feature/grih-025-repeat-visit-history` branch from the agreed integration
branch before opening the PR if the team requires branch isolation.

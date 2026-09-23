# Reorder Rules and Risk Thresholds — P6-C
Version: rules-v1.0 · 2026-09-22 · Deterministic, no model. Matches WST-FR-14 (rules first, model optional and only after enough history, human override, non-AI fallback).

## 1. Reorder suggestion (inventory)

**Inputs**, all from the stock ledger (`stock_movement`) and `part`:
- `on_hand` and `reserved` — from the `stock_balance` view
- `open_po_quantity` — sum of `purchase_order_line.quantity - received_quantity` on orders not yet fully received
- `min_level`, `max_level` — from `part`
- `avg_weekly_consumption` — average of `ISSUE` quantities over the last 4 weeks, per part and store

**Rule:**
```
available = on_hand - reserved + open_po_quantity
suggest a reorder when available <= min_level
suggested_quantity = max_level - available
weeks_of_cover = available / avg_weekly_consumption   (shown as the explanation)
```
Never places an order automatically — a storekeeper or procurement user accepts or overrides it. The decision (accepted / overridden / ignored) is recorded, matching FR-14's acceptance evidence.

**Where this was demonstrated in the seed:** 8 parts were written down to or below their minimum level on the last day of the workshop seed (`P23-E`, `P42-E`, `P29-P` at 0 available; `P39-E`, `P25-P`, `P31-P`, `P33-P`, `P15-E` at 1). Query `stock_balance` joined to `part` to see them.

## 2. Training completion-risk flag

**Inputs**, all from `attendance`, `assessment` and `enrollment`, snapshotted after session 5 of 10 (the course midpoint):
- `attendance_rate` — attended sessions ÷ sessions held so far
- `missed_assessments` — tasks due by this point with no result at all
- `pending_unsigned` — results entered but not yet signed by the supervisor
- `fail_or_ni_count` — results marked FAIL or NEEDS_IMPROVEMENT
- `competency_coverage` — signed PASS tasks ÷ tasks due

**No protected or sensitive attribute is used or stored for this rule** (no gender, age, health, income, disability, or similar field exists on `app_user` for students).

**Rule (points, then a flag):**

| Condition | Points |
|---|---|
| Attendance rate below 60% | 2 |
| Attendance rate 60–74% | 1 |
| 2 or more tasks due but never assessed | 2 |
| Exactly 1 task due but never assessed | 1 |
| 2 or more assessed results still unsigned | 2 |
| Signed-pass coverage of due tasks below 50% | 1 |
| 2 or more non-pass (FAIL/NEEDS_IMPROVEMENT) results | 2 |
| Exactly 1 non-pass result | 1 |

**Flag:** `High` at 4 points or more, `Medium` at 2–3, `Low` otherwise.

**Explanation shown to the user:** the specific conditions that fired (e.g. "Attendance 58% is below 60%", "2 assessments still unsigned"), not just the flag or the score. This is the same explanation whether the rule or the trained model produced the number (see `P6-C_Model_Metrics_and_Version.json`).

**Fallback:** if the trained model is unavailable, use this rule directly — same inputs, no retraining or reconnection needed.

**Thresholds are placeholders.** Both the point weights above and the reorder `min_level`/`max_level` formula need sign-off from the workshop manager and training supervisor before being presented as final — say this explicitly in the demo and the report.

## 3. Where each demo case sits (seed data)

| Case | Rule points | Flag |
|---|---|---|
| CERTIFIED students (7) | 0 | Low |
| PENDING_SIGNOFF students (4) | 2 (pending_unsigned) | Medium |
| LOW_ATTENDANCE students (4) | 2 (attendance) + 2 (missed) | High |
| NEEDS_IMPROVEMENT students (4) | 2 (fail_or_ni_count) | Medium |

Recomputed from `seed_features_snapshot.csv` in the student data package.

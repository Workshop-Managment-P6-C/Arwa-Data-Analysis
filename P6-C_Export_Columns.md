# Dashboard Export Columns — P6-C
Version: exports-v1.0 · 2026-09-22 · Matches WST-FR-13 (filtered CSV/PDF exports that reconcile to source).

Common rules for every export:
- Filters used on screen (date range, role scope, store, course) are shown in a header row/line of the export itself, so the file is self-describing.
- Every export is one flat table — no merged cells, no sub-totals inside the rows — so the totals can be recomputed by anyone from the raw rows.
- Money columns state the currency (EGP, see `P6-C_q1_q2_and_Currency.md`) in the column header, not just the value.
- All timestamps export in the viewer's local time, not UTC.

## 1. Job pipeline export (workshop manager)
`job_number, vehicle_plate, customer_name, service_type, priority, stage, bay, technician, advisor, created_at, promised_at, delivered_at, turnaround_hours`

## 2. Stock health export (storekeeper)
`sku, name_en, category, store_code, on_hand, reserved, available, min_level, max_level, weeks_of_cover, reorder_suggested (Y/N)`

## 3. Purchase orders export (storekeeper / procurement)
`po_number, vendor_name, status, total_amount_egp, approvals_required, approval1_by, approval1_at, approval2_by, approval2_at, submitted_at`

## 4. Revenue and cost summary export (finance viewer)
`invoice_number, job_number, status, subtotal_egp, discount_egp, tax_egp, total_amount_egp, issued_at, paid_amount_egp, paid_at`

## 5. Training attendance export (training supervisor)
`student_code, course_code, session_no, session_date, status (present/absent/late/excused)`

## 6. Assessment and competency export (training supervisor)
`student_code, course_code, task_code, result, time_on_task_minutes, entered_by, signed_by, signed_at, competency_code, competency_covered (Y/N)`

## 7. Training-risk export (training supervisor)
`student_code, course_code, attendance_rate, missed_assessments, pending_unsigned, fail_or_ni_count, competency_coverage, rule_score, rule_flag, reasons`
Reasons is a semicolon-separated list of the specific conditions that fired (see `P6-C_Reorder_Rules_and_Risk_Thresholds.md`).

## 8. Certificates export (training supervisor / auditor)
`student_code, course_code, status (issued/revoked), issued_at, revoked_at, revoked_reason, verification_token`
The verification token is only shown in this internal export — the public verification page never exposes it in a list, only checks one token at a time.

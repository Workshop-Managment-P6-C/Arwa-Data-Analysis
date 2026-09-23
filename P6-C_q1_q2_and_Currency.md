# Cost Tertiles (q1/q2) and Currency — P6-C
Version: pricing-v1.0 · 2026-09-22 · Computed from the actual workshop seed's 343 invoices (`P6-C_workshop_seed_mysql.sql`), not the Kaggle vehicle dataset.

## Currency
All money values in the database (`part.average_cost`, `purchase_order.total_amount`, `invoice.*`) are in **EGP (demo currency, not a real transaction)**. The currency is fixed for the whole system — there is no multi-currency support and none is required by the brief. Show "EGP" or "ج.م" next to every amount in the UI and in exports (see `P6-C_Export_Columns.md`).

Configuration values used when the seed was generated:
| Setting | Value |
|---|---|
| Labour rate | 300 EGP / hour |
| Tax rate | 14% |
| Purchase-order two-approval threshold | 15,000 EGP |

These are demo defaults, not fixed by the brief — a workshop manager should be able to change them, and the invoice must still recompute correctly from source lines (FR-09).

## Invoice cost tertiles (q1 / q2)
Computed from `invoice.total_amount` across all 343 seeded invoices:

| Cut point | Value (EGP) |
|---|---|
| q1 (33rd percentile) | 695.07 |
| q2 (67th percentile) | 1,442.24 |
| Minimum | 126.54 |
| Maximum | 10,854.75 |
| Average | 1,415.84 |

**Suggested bucket, for a "job cost" dashboard filter (not a stored column — compute it at query time):**
```sql
CASE
  WHEN total_amount <= 695.07  THEN 'Low'
  WHEN total_amount <= 1442.24 THEN 'Medium'
  ELSE 'High'
END AS cost_category
```
This gives close to an even three-way split on the seeded data (115 / 114 / 114 invoices). Recompute q1/q2 periodically as real invoices accumulate — these are not fixed constants, they describe the current data.

**Not to be confused with:** the Kaggle "Vehicle Maintenance - Service Records" dataset's own `Cost_Category` (Low/Medium/High) and its q1/q2 cut points (about 4,189 / 6,147, in Indian rupees, from a completely different dataset of car repairs unrelated to this project). If a notebook trains a cost model on that dataset, its price bands describe that dataset only and should not be shown as P6-C's own pricing.

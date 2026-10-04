# Workspace dataset profile and execution summary

**Scope:** every data file currently present under `data/demo/`. The accompanying
`data/demo/README.md` explicitly states these values are fabricated testing
fixtures; findings below are calculations on those workspace fixtures only,
not verified observations about Savanna Retail Group. Per the user's instruction,
this directory was treated as the complete available dataset for this run.

## File inventory

See `output/workspace_dataset_inventory.csv` for row/event counts, hashes,
byte sizes, and explicit missing-file entries. Present files: customer,
product, sales, supplier, loyalty, synthetic HR sample, and synthetic footfall
sample. Not present: the assignment `etl_error_log.txt` and `SRG_HR.xlsx`.

## Profile metrics

See `output/workspace_quality_profile.csv` for numerator, denominator,
percentage (where meaningful), rule, phase, and limitation for each metric.
Customer/product before-and-after metrics are also in
`output/quality_metrics.csv`. Accuracy and timeliness are marked not measured
where no independent reference, arrival timestamp, or SLA exists.

### Executed sales fixture results

- Rows read: **8**; accepted: **7**; quarantined:
  **1**. The sole rejected record is reported with source
  record and reason in `output/sales_rejects.csv`.
- Accepted synthetic net amount: **UGX 50400**;
  accepted net quantity: **9**; lines with negative quantity:
  **1**. Amount is a computed fixture total, not a validated SRG total.
- Missing payment references: **1 of 8**. These
  remain explicitly marked for Finance; the missing value is not fabricated.
- Negative quantity lines with a reason: **1 of 1**.
  Return quantity and amount remain negative in the analytics fact by design.
- Duplicate source order/line keys: **0**. No duplicate line keys
  were observed in the fixture.

| SKU | Accepted lines | Net amount (UGX in fixture) | Net units |
|---|---:|---:|---:|
| SNK-001 | 2 | 13500 | 3 |
| DRK-003 | 1 | 9000 | 3 |
| HOM-004 | 2 | 24000 | 2 |
| GRN-005 | 1 | -2500 | -1 |
| DRK-002 | 1 | 6400 | 2 |
## Cleansing decisions and assumptions

1. Phone normalization is only for recognizable Ugandan formats; malformed or
   missing numbers remain unresolved. Matching numbers create a review candidate,
   never an automatic identity merge.
2. `KLA` is mapped to Kampala and the fixture's listed districts are accepted
   only as a demonstration reference; an owner-approved reference is required
   for production.
3. Unit aliases `kg/KGS/Kilograms` and `L/lt/Litre` normalize to kg/L.
   Pack-size and variable-weight conversions require procurement approval.
4. Ambiguous slash dates are quarantined rather than interpreted by locale.
   The rejected P002 record shows this rule in use.
5. A three-letter currency string is a syntax check only. FX conversion and
   authoritative settlement are not inferred.
6. CSV files are the supplied representation. `SRG_HR_SAMPLE.csv` is treated
   only as a one-row schema example, not as the requested HR workbook.
7. The missing `etl_error_log.txt` is not replaced with a fabricated log.
   The successful run transcript at `output/postgres-demo-etl-log.txt` is
   execution evidence, not evidence of the assignment's broken job.

## ETL log diagnosis

No `etl_error_log.txt` exists anywhere in the workspace inventory. Therefore,
there is no evidence from which to identify a specific broken-job root cause.
The reproducible SQL path itself was executed twice: seven rows stage and load,
the second run upserts rather than duplicates facts, the ambiguous-date row is
excluded, and the explained return remains negative. The only error observed
in the RBAC test is the expected permission denial when analytics attempts
restricted access; it is a passing security control, not an ETL failure.

For the absent broken-job log, diagnosis remains **not evidenced**. Inspect its
first exception, job/run ID, watermarks, source schema/counts, credentials,
network/lock events, transaction boundaries, and partial target state when a
real log is supplied. Do not claim any one hypothesis as the cause.

## Remaining validity limits

These fixture sizes (customers=8, products=6,
sales=8, suppliers=2, loyalty=3,
footfall events=3)
are smaller than the scale stated in the assignment scenario. Thus, this run
demonstrates the profiling/ETL scripts and provides exact results for current
files, but does not validate scenario-scale percentages, business trends,
stock-variance root cause, or actual HR exposure.

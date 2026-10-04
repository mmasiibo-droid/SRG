# Broken ETL log diagnosis — evidence template

**Workspace result:** `etl_error_log.txt` is not present in the recorded
workspace inventory for this run. A specific root cause cannot be inferred
from an absent log. The SQL pipeline execution transcript is available at
`output/postgres-demo-etl-log.txt`; it records successful staging and two
successful idempotent ETL runs on the demo data, not the assignment's broken
job.

The observed pipeline results were: 7 fixture rows staged, 7 promoted in the
first run, and 7 still present after replay; the ambiguous-date order was
excluded; the documented return remained negative. The expected denial when
the analytics role attempted restricted-schema access is an RBAC pass, not an
ETL error.

Use the template below if the broken-job log is later supplied. Do not convert
the candidate causes into findings without log evidence.

| Evidence | Capture |
|---|---|
| File/run ID, start/end, environment | |
| First exception and stack (not only final retry) | |
| Failing task/table/partition and source watermark | |
| Expected / extracted / transformed / loaded / rejected counts | |
| Source schema and file hash vs prior successful run | |
| Credential/secret rotation or permission change | |
| Network, timeout, lock, disk, and memory evidence | |
| Target transaction state, duplicate keys, partial commits | |
| Reproduction on a copied/quarantined batch | |

Hypotheses to test: null/type conversion, changed source schema, duplicate-key
retry, expired credentials, connectivity/timeout, lock/contention, and
watermark advancement before a transaction commits. For each supported cause,
record corrective action, preventive test/alert, owner, and a replay procedure.
Restore from immutable raw input; make loads idempotent; reconcile counts and
financial control totals before advancing a watermark.

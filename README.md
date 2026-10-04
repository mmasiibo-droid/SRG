# Project Savanna — EDM turnaround portfolio

This folder contains an AI-assisted, reproducible working portfolio for the
individual capstone described in [Enterprize.pdf](./Enterprize.pdf). All files
currently present in the workspace were inventoried and profiled as requested.
The README under `data/demo/` identifies its records as fabricated test
fixtures; calculated results therefore describe those files only, not SRG.

## Contents

- `docs/portfolio.md` — report narrative and evidence limitations.
- `docs/finalization-checklist.md` — completed work and outstanding evidence gates.
- `docs/diagrams/` — editable Mermaid architecture, lifecycle, ER, lineage,
  integration, and root-cause diagrams.
- `docs/assumptions-register.csv`, `docs/decision-log.csv`,
  `docs/risk-register.csv`, and `docs/data-dictionary.csv` — working registers.
- `docs/legal-citation-review.md` — verified GDPR article references and the
  remaining Uganda primary-source verification limit.
- `docs/reflective-essay-draft.md` — project-based reflection and tentative
  learning/career plan for personal review.
- `data/demo/` — small synthetic source files for exercising the pipeline.
- `scripts/` — PowerShell profiling, cleansing, masking, and validation.
- `sql/` — PostgreSQL operational/warehouse schema, ETL examples, and RBAC.
- `dashboard/index.html` — offline, filterable dashboard using synthetic data.
- `dashboard/dashboard-demo.png` — screenshot of the synthetic dashboard.
- `dashboard/demo-data.js` — generated aggregates from currently accepted workspace sales rows.
- `dashboard/workspace-synthetic-sales-aggregates.csv` — grouped,
  publication-safe Tableau import data; synthetic fixture values only.
- `docs/dashboard-publication.md` — Tableau Public import/publish steps and
  current sign-in/publication status.
- `output/workspace-data-profile.md` — results and evidence limitations for every available input.
- `output/workspace_dataset_inventory.csv` — hashed input inventory, including missing-file entries.
- `output/workspace_quality_profile.csv` — cross-source rule/metric/limitation rows.
- `output/Project-Savanna-Portfolio-DRAFT.pdf` — consolidated working-draft PDF, including profile and readiness appendices.
- `Enterprize.pdf` — the supplied assignment brief.

## Run the reproducible demo (Windows PowerShell)

From this folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-demo.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-pipeline.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-postgres.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\render-portfolio.ps1
```

`run-demo.ps1` profiles every CSV/JSON fixture currently under `data/demo/`,
writes the inventory and cross-source quality profile, cleans customer/product/
sales rows, and generates `dashboard/demo-data.js` from accepted sales. The
exact calculations are in `output/workspace-data-profile.md`,
`output/workspace_dataset_inventory.csv`, `output/workspace_quality_profile.csv`,
and `output/quality_metrics.csv`. The fixture README explicitly labels records
as fabricated, so these results demonstrate behavior on the complete files
currently in this workspace only; do not present them as SRG business results.

The assignment's named `etl_error_log.txt` and `SRG_HR.xlsx` are not in the
workspace. Their absence and the resulting limits are in the inventory,
Assumptions Register, and portfolio appendix. The available
`SRG_HR_SAMPLE.csv` is profiled as a schema example only. The successful
PostgreSQL execution transcript is not substituted for the missing broken-job
log.

To use compatible CSVs from another authorized source, run
`scripts\profile-and-clean.ps1 -InputDirectory <folder> -OutputDirectory <folder>`.
Keep real inputs and outputs outside version control and restrict access.

If you run it on real records, restrict the output folder: cleaned source
columns and transaction references remain sensitive. Never commit real
input/output data. The duplicate review export uses opaque group IDs instead
of writing phone/email match keys.

`test-postgres.ps1` loads the synthetic sales rows into the disposable
`savanna_edm_demo` PostgreSQL database, applies the seed and ETL scripts twice,
and checks accepted rows, returns, invalid dates, and idempotent replay. It
replaces only the staging rows for its fixed synthetic batch and upserts
synthetic fact rows; do not point it at a production or shared database.
It also verifies that the analytics role can read its masked view but cannot
read restricted customer fields, and writes execution transcripts to `output/`.
The current local database contains seven synthetic staged sales rows and
seven synthetic warehouse fact rows; the restricted customer table is empty.
Connect with `psql -h localhost -U postgres -d savanna_edm_demo` and enter the
database password when prompted. Do not place the password on the command
line or in a project file.
PostgreSQL scripts target PostgreSQL 14 or later. Never paste passwords into
scripts or grant demo privileges in production. The dashboard opens as a local
HTML file and does not publish data to a third party.

## Before treating this as a submission

1. This run treats the workspace files as the complete available dataset.
   If the instructor later supplies actual CSV/XLSX/log/JSON records, inventory
   and profile those separately and revise the report using the new evidence.
2. GDPR article references have been checked against EUR-Lex. Verify Uganda
   section-level duties and notification deadlines against current official
   text or with qualified counsel; see `docs/legal-citation-review.md`.
3. Review the findings, assumptions, budget, and career-path reflection yourself.
   Add a truthful AI-assistance declaration consistent with KIU policy and be
   prepared to explain every artifact in the viva.
4. Publish a dashboard only after approval, access review, masking, and use of
   actual authorized data. Tableau Public website sign-in is complete and the
   local synthetic worksheet is open, but Tableau 2023.2 desktop
   authentication still fails with `ERR_CONNECTION_RESET`; no dashboard has
   been published and no external URL is claimed. Only synthetic fixture data
   are present.

## Evidence status

| Evidence | Status |
|---|---|
| Scenario facts and requirements | Transcribed from supplied assignment brief |
| Customer/product quality figures | Calculated on 8 customer and 6 product fixture rows; not SRG estimates |
| Workspace profiles / cleansing | Synthetic fixtures; `output/quality_metrics.csv` and `output/workspace_quality_profile.csv` |
| PostgreSQL schema and RBAC | Applied to local `savanna_edm_demo`; negative access check passed |
| PostgreSQL ETL | Synthetic staging-to-fact replay test passed; see `output/postgres-demo-verification.txt` |
| ETL error diagnosis | No root cause evidenced: `etl_error_log.txt` absent; successful local test is not the missing failure log |
| HR sensitive-field inventory | One-row schema sample only; `SRG_HR.xlsx` absent |
| Sensor processing behavior | Three fabricated events profiled; not production behavior |
| Dashboard findings | Synthetic demonstration only; not SRG findings |
| Published dashboard and screenshots | Not supplied; publishing requires authorized data/account |

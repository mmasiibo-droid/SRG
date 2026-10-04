# Final-submission readiness checklist

**Current state: complete for the files available in this workspace; still a
working draft rather than a verified final SRG business analysis.** The user
instructed us to treat the present workspace dataset as the complete provided
set. The fixture README itself describes those values as fabricated. This
report therefore gives calculated results for the current files without
presenting them as real SRG observations.

## Completed and verified

- [x] Assignment brief copied into the project.
- [x] Consultancy report, board memo, architecture/design recommendations,
  governance/RACI, risk and decision registers, DPIA working draft, data
  dictionary, validation rules, and source diagrams created.
- [x] All available customer, product, sales, supplier, loyalty, HR-schema, and
  footfall files inventoried with hashes and profiled; report caveats preserved.
- [x] PowerShell demo pipeline generates standardized outputs, review queues,
  masking, and before/after profile metrics.
- [x] Sixteen pipeline assertions pass.
- [x] PostgreSQL 17 schema and RBAC applied to local `savanna_edm_demo`.
- [x] Synthetic staging/ETL re-run test passes; seven accepted fact rows are
  stable after replay, one ambiguous date is excluded, and a documented return
  remains negative.
- [x] Negative RBAC evidence: `srg_analytics` can read the masked view and is
  denied access to the restricted schema/table.
- [x] Local interactive synthetic dashboard and screenshot created.
- [x] Dashboard data regenerated from accepted sales rows, not hand-entered
  example values.
- [x] Cross-source completeness, validity, consistency, uniqueness, privacy
  schema, and measurable/unmeasurable accuracy/timeliness indicators exported.
- [x] ETL log diagnosis recorded as not evidenced because the named file is not
  in the full workspace inventory; successful local ETL and expected RBAC
  denial are distinguished from the absent broken-job log.
- [x] GDPR article references and breach-notification qualifiers checked
  against EUR-Lex; Uganda Act source limitation recorded without inventing
  section numbers or a notification deadline.
- [x] Project-based first-person reflection added with a practical development
  plan; it avoids invented biography and marks career direction as tentative.
- [x] Publication-safe, grouped sales aggregate CSV generated for Tableau;
  customer/order/payment identifiers are excluded.
- [x] Tableau Public website sign-in confirmed; safe CSV opened in local
  Tableau Public and a worksheet created.
- [x] Consolidated 33-page working-draft PDF rendered under the assignment's
  40-page limit.

## Evidence files absent from this workspace

The available data directory contains `data/demo/`. The workspace inventory
lists every present file, byte size, SHA-256, and these absent assignment files:

- `SRG_Customers.csv` and `SRG_Products.csv` at the actual assignment scale.
- `SRG_Sales.csv` and its unnormalized source extract.
- `SRG_Suppliers.csv` and `SRG_Loyalty.csv` actual source files.
- `SRG_HR.xlsx` (so actual sensitive-column inventory is unknown).
- `etl_error_log.txt` (so a specific root cause cannot be stated).
- `footfall_stream_sample.json` (only a fabricated demo stream exists).

The current deliverable handles these gaps with explicit assumptions and
does not invent values, a diagnosis, or workbook fields. If a later version of
the assignment includes them, revise the report and recalculate rather than
silently mixing versions.

## Blocked: student-specific or external actions

- **Reflection/career plan:** review
  `reflective-essay-draft.md` in your own voice. The proposed entry-level data
  management/analytics direction is tentative; change it if it does not fit
  your actual interests and current skills.
- **AI-use statement:** add the exact disclosure required by KIU policy; do
  not remove the existing disclosure of AI assistance.
- **Uganda legal references:** confirm exact section numbers and applicable
  duties/deadlines against the current official Act, regulations, and PDPO
  guidance or with qualified counsel. See `legal-citation-review.md`; the
  official PDPO Act link returned an application shell during this check, so
  the portfolio deliberately asserts no Uganda notification deadline.
- **Tableau Public publication:** import the safe aggregate CSV using
  `docs/dashboard-publication.md`; the owner has signed in, the worksheet is
  open locally, and its seven marks total UGX 50,400. Native requests to the
  Tableau Public `/app` routes return HTTP 200, but the Tableau 2023.2 desktop
  sign-in still fails with `ERR_CONNECTION_RESET`. Authenticate in the desktop
  client (or use an updated client), finish the view/dashboard, and save
  publicly only after confirming a fully public workbook is acceptable. Add
  and verify the genuine live URL afterward.
- **Final authorship/viva:** check every assumption and finding, add your own
  decisions/evidence, and make sure you can explain each SQL/script/diagram in
  the viva.

## Re-finalize after completing blockers

1. Update the report, evidence registers, dashboard, and this checklist.
2. Run `scripts\test-pipeline.ps1` and `scripts\test-postgres.ps1` against a
   disposable database only.
3. Run `scripts\render-portfolio.ps1` and confirm the PDF page count remains
   within the course limit.
4. Review the PDF and all linked artifacts manually before submission.

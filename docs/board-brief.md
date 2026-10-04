# Board briefing memo

**To:** Board of Directors, Savanna Retail Group  
**From:** Enterprise Data Management Consultant (working draft)  
**Subject:** Control the data causes, not only the database symptoms  
**Decision requested:** Approve a six-month, two-store pilot and release funding
by phase, within the stated UGX 480M envelope.

## Why action is needed

SRG's reported symptoms are linked: 23% duplicate customer records, wrong
loyalty awards, five product identifiers for the same item, 11 days to prepare
monthly reports, an 8.4% stock variance, and an unencrypted laptop with 9,000
customer records that was reported internally 11 days late. Each number comes
from the supplied scenario brief and has not been independently recalculated.
The instructor datasets and incident evidence were not provided with the PDF.

Hiring two database administrators would help maintain availability, backups,
indexes, and access controls. It would not decide who owns a customer identity,
which supplier SKU maps to a product, whether an offline signup may be merged,
which report definition the Board should trust, how long an export may be kept,
or who assesses and reports a suspected breach. Those are enterprise data
management decisions involving operational owners, IT, privacy, Finance, and
the Board.

## Recommended operating model

Select a hub-and-spoke architecture with local operation during outages and a
governed integration/MDM hub for replay, reconciliation, and cross-system
identifiers. Keep existing transactional systems during the pilot. A store
that loses its connection must still sell; an offline customer gets a
provisional local ID, not another customer's points. Identity matches require
strong evidence or human review and must be reversible.

Begin with controls that reduce immediate exposure: prohibit unencrypted
exports, require encrypted endpoints and approved access, record an export
owner/purpose/expiry, rehearse incident escalation, and test recovery. In
parallel, assign data owners and stewards, approve a product/unit reference,
and automate daily sales reconciliation. Build a relational warehouse and
role-filtered dashboard from reconciled batch data. Consider near-real-time
processing only for a measured use case such as a selected stock-out alert or
aggregate store queue count.

## Six-month outcomes

By month 3, have a named incident lead, an export register, an access review,
owners for customer/product/sales data, and a measured data-quality baseline.
By month 6, complete a two-store offline/replay pilot with no duplicate sales
on retry, publish a daily reconciled sales report, route unmapped SKUs and
identity candidates to named stewards, and demonstrate a masked dashboard
refresh with visible source and refresh time. Pause expansion if privacy,
restore, reconciliation, or store-acceptance tests fail.

## Cost and risk discipline

The attached working allocation sums to UGX 480M: staff/backfill/training 72M;
connectivity/edge/UPS 50M; endpoint/database security and recovery 65M;
software/support 45M; integration/warehouse 90M; privacy/legal/audit 40M;
quality/MDM 45M; dashboard/adoption 22M; controlled contingency 51M. These
are planning allocations, not vendor quotes. CFO approval should require
current total-cost estimates, recurring costs, taxes, and named exit criteria
for each phase. Do not commit contingency to unmeasured streaming or an
enterprise catalog.

## The Board's role

Name the COO as sponsor, require owners to accept measurable quality and
retention controls, and review monthly risk/benefit evidence. Ask for evidence
of reconciliation, recovery, access, and customer-rights handling—not a count
of tools installed. A legal review must verify Uganda obligations and EU
transfer/breach duties before relying on any compliance conclusion. The first
release is a controlled pilot, not a promise that every dataset is already
accurate or that the scenario's reported figures have been validated.


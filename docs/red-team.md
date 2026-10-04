# Red-team critique of the proposed strategy

**AI-assisted draft for individual review.** The strongest case against this
strategy is that its apparent simplicity hides an operating burden SRG may not
be able to carry. Four IT staff, only two of whom write SQL, are already
supporting 23 disconnected POS installations, an e-commerce site, a mobile
loyalty application, CRM, Odoo, payroll, supplier spreadsheets, and manual
payment reconciliation. Adding an integration hub, warehouse, Type-2
dimensions, identity crosswalk, security logs, and a governance council creates
more components to patch and more failure modes. A six-month “quick win” can
become another pilot that works at HQ but fails at remote stores. If the team
cannot monitor retries, resolve schema drift, restore backups, and explain
failed loads, the new platform may merely move spreadsheet work into
unmaintained pipelines.

The hub-and-spoke choice also risks central political capture. A central
customer owner may label a store's legitimate local signup “bad data” and
prevent sales; a marketing owner may use the golden record to expand profiling
beyond what customers understood. A council chaired by executives can silence
stewards who report poor source data, while the IT team is blamed for defects
created by incentives and rushed procedures. A provisional offline ID avoids
blocking checkouts, but synchronization can still award points to the wrong
person or replay a sale twice. The strategy's thresholds (95 for auto-link,
75 for review) look precise despite having no adjudicated training set. If
management treats them as scientifically validated, automation could multiply
identity errors at scale.

The cost estimate is another weak point. UGX 480 million is both a hard
scenario limit and a budget that must cover licenses, cloud, staff time,
security, legal review, hardware, and connectivity. The line items are
planning placeholders, not vendor quotations. Taxes, implementation, support,
exchange rates, replacement devices, data transfer, and recurring fees can
consume the contingency. A managed catalog or cloud service may add foreign
currency exposure and processor/transfer obligations. If the budget is cut or
spent early, an unfinished hybrid estate could be less secure than today's
systems.

Connectivity and power are not temporary nuisances. Buffering events at a
store creates a local cache of customer and transaction data; that cache needs
encryption, key recovery, expiry, tamper resistance, conflict handling, and
support when a device is replaced. If these controls depend on stable internet,
stores may bypass them. If they depend on local expertise, outages will produce
unrecoverable queues. A nightly ETL job can also produce misleading totals if
late transactions arrive after a stock or sales snapshot; fast dashboards do
not fix inconsistent source clocks or incomplete returns.

Privacy controls can fail in subtler ways. Masked values are often
pseudonymous, and stable IDs still permit linkage. A “coarse” footfall stream
may become identifying when joined with a rare purchase or shift schedule.
Retention periods are deliberately left for legal review, but delays in setting
them could permit indefinite copies. The report cites comparative breach cases
without treating them as SRG cost estimates; nonetheless, those examples can
distort a CFO decision if local legal exposure, customer behavior, and recovery
costs differ.

The rebuttal is not to ignore these objections but to make each a release
gate. Do not expand beyond two representative stores until tests prove
idempotent replay, conflict resolution, backup restoration, and staff
acceptance. Keep source systems operational and make the hub rebuildable from
versioned exports. Make matching thresholds provisional and prohibit automated
merge until a reviewed sample shows acceptable false-merge rates across
district/name groups. Use a council charter with published exception metrics
and an escalation path outside the data owner. Stage vendor decisions against
written total-cost and legal reviews; if funding is insufficient, defer the
catalog, streaming, and broad cloud migration before deferring encryption,
incident response, access review, or backups.

Some objections may still win. If remote stores cannot reliably protect and
replay queued records, the correct answer is not to force a central real-time
signup; keep provisional local identities and defer point transfers until
review. If counsel cannot approve the EU transfer model, postpone that rollout.
If the BI dataset cannot be reconciled to finance, withhold the Board dashboard
rather than decorate uncertainty with charts. The strategy should be judged by
measured error reduction, timely incident handling, restored service, and
staff use—not by how many tools were installed.

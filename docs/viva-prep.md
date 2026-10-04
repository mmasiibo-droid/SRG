# Viva preparation

Practice answering these in your own words. All example claims must be checked
against actual project evidence.

1. **Why hub-and-spoke instead of centralizing POS?** Preserve offline checkout
   and reconcile idempotently when connectivity returns; test two stores first.
2. **What happens to an offline customer signup?** Create a source-prefixed
   provisional ID, record purpose and source event, queue it securely, award no
   points to a guessed identity, and reconcile/review after sync.
3. **Why does a 95 match score not prove identity?** Weights are heuristics, not
   calibrated probabilities; require multiple independent attributes and a
   false-merge validation set.
4. **How do you diagnose 8.4% variance?** Align SKU/unit/store/time grains,
   match receipts, sales, returns and cycle counts, separate timing from
   shrinkage, and validate causes before adjusting stock.
5. **What could break the ETL?** Schema drift, locale/date ambiguity, duplicate
   replay, expired credentials, delayed offline events, and a watermark
   committed before facts. Explain quarantine, transaction, replay and
   reconciliation.
6. **What would you do with half the budget?** Preserve incident controls,
   endpoint encryption, recovery, access, minimum owner/steward capacity, and
   daily finance reconciliation; defer streaming, broad cloud migration,
   commercial catalog, and rollout beyond pilot.
7. **Why not real-time everything?** Only pay for latency where a faster signal
   changes an action. Most finance reporting and trend analysis can be daily;
   broad streaming increases cost and operational failure modes.
8. **What is masked data?** Pseudonymized data can still be linkable; protect
   stable IDs, limit access, and do not call it anonymous without a risk test.
9. **What legal conclusion needs counsel?** Uganda registration and breach
   duties, GDPR territorial scope and transfer mechanism, CCPA applicability,
   retention, and any regulator/data-subject notification decision.
10. **What is your authorship/AI declaration?** Give a truthful account of
    which tools assisted, what you verified, what you changed, and demonstrate
    understanding of every artifact.

# DPIA working template — proposed EU-facing loyalty rollout

**Status: not approved; facts and legal basis must be confirmed.** This is a
structured draft, not a completed legal DPIA or transfer assessment.

## Processing description

- **Purpose:** loyalty administration and, only where justified and enabled,
  personalized offers. Separate essential account processing from optional
  marketing.
- **People/data:** adult and potentially household customers; identifiers,
  contact details, purchases, points, preferences, consent/objection records.
  Exclude precise location and sensitive-category inference by default.
- **Systems/recipients:** loyalty application, POS/e-commerce, CRM, integration
  hub, processors, analytics; identify actual hosting regions/subprocessors.
- **Retention:** propose purpose-specific periods and deletion across source,
  replicas, exports, and backups after counsel validates statutory/contractual
  needs. No default period is asserted.
- **Transfers:** map Uganda/EU/other hosting and access locations; establish
  applicable GDPR Chapter V mechanism before any restricted transfer.

## Necessity, proportionality, risks, mitigations

| Risk | Harm | Safeguard / evidence required |
|---|---|---|
| Wrong customer match | Purchases exposed; points misallocated; rights history corrupted | Conservative thresholds, human review, reversible merge, access/audit logs |
| Consent or purpose ambiguity | Unwanted profiling/marketing | Separate purposes, clear notices, granular choices, withdrawal propagation |
| Breach of contact/purchase history | Fraud, embarrassment, loss of trust | Encryption, least privilege, MFA, monitored exports, tested incident response |
| Household/shared identifier | One person's activity attributed to another | Phone not a sole identifier; no household inference without defined purpose |
| Cross-border access | Unlawful transfer or weak redress | Data-flow map, processor due diligence, approved transfer mechanism and counsel |
| Biased matching | Unequal false-match rates by names/language/district | Representative reviewed validation set, subgroup error review, appeal and rollback |
| Function creep | Loyalty data reused beyond expectation | Purpose registry, access separation, council approval, documented compatibility review |

Assess necessity against less intrusive alternatives, data minimization,
expected benefit, and the residual risk to individuals. Obtain controller/DPO
and counsel sign-off, consult a supervisory authority where legally required,
and do not launch if high residual risk remains without the required process.
Record data-subject rights, processor terms, security tests, retention evidence,
breach contacts, and transfer mechanism before rollout.


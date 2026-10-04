# Reflection on the Project Savanna portfolio

This project changed how I think about data work. At the start, it was easy to
see the brief as a technology problem: connect several systems, clean the
records, and build a dashboard. Working through the design and the available
files made that view feel incomplete. A system can move data quickly and still
produce a misleading answer. The harder work is agreeing what a record means,
who is responsible for it, and what the evidence can honestly support.

One practical lesson came from profiling the files in the workspace. The
customer, product, sales, supplier, loyalty, HR-schema, and footfall examples
looked like the inputs needed for analysis, but the data README identifies
them as fabricated test fixtures. I could calculate exact results for those
files, including seven accepted sales rows and one ambiguous date quarantined,
but I could not turn them into claims about SRG. That distinction matters.
Numbers can look authoritative simply because they have decimal places or sit
in a polished report. I now see provenance, denominators, and limitations as
part of the result, not footnotes to add later.

The same discipline shaped the ETL diagnosis. The requested error log was not
present, so there was no defensible way to name the cause of the assignment's
broken job. The local PostgreSQL test did run successfully and could be
replayed without creating duplicate facts, but that only demonstrates the
test pipeline. The rejected ambiguous date and the expected access-denied
result each have different meanings. Separating those cases taught me to
describe what happened before reaching for a root-cause explanation. It is
better to report a clear evidence gap than to fill it with a plausible story.

The data model also raised a useful question about identity. A matching phone
number is not proof that two rows describe the same person. People share
phones, change numbers, and sometimes choose not to provide one. A reversible
crosswalk and a human review queue are less tidy than automatic merging, but
they leave room to correct mistakes. I would rather preserve a little
duplication temporarily than combine two people's histories without a sound
basis. This is a technical choice with consequences for privacy, fairness,
loyalty points, and the customer's ability to challenge an error.

The proposed store design asks for a similar balance. Intermittent power and
connectivity are not edge cases if staff encounter them as part of ordinary
work. An online-only design would make a store's service depend on conditions
outside its control. Keeping local operations usable and reconciling signed,
idempotent events later is more complicated, but more realistic. It also
requires clear conflict rules and monitoring; “offline first” is not a reason
to ignore data quality.

Privacy decisions need the same practical attention. A loyalty service may
need contact details to operate an account, but marketing and detailed
personalization are separate purposes that should be explained and controlled.
Footfall counts may help with staffing, while joining movement histories to
loyalty profiles would create a much more intrusive system. I learned not to
equate technical ability with permission or necessity. Before collecting a
new field, I should be able to explain its purpose, access, retention, and
the less intrusive alternatives considered.

The dashboard work reinforced that presentation is part of responsible
analysis. The local page now reads aggregates generated from accepted fixture
rows, and its filters and return values can be checked. It is still only a
demonstration. A useful chart should make its grain, time period, currency,
and limitations visible; it should not make a small synthetic sample look
like a business trend. I also learned to distinguish a working artifact from
a published service. A local HTML page is not a governed production dashboard.

I used AI assistance while preparing this portfolio, so I also had to think
about how to check work that can sound confident. Generated text and code
need to be compared with source files, test results, and the assignment
requirements. In this case, the scripts, PostgreSQL checks, and calculated
profiles provide evidence for specific technical claims, while the legal
citations and scenario-scale business conclusions have limits that must stay
visible. My responsibility is not removed by using a tool; it includes
reviewing its output and disclosing the assistance according to course policy.

For my next step, I would like to build toward an entry-level data management
or analytics role, while learning more about which parts of the work suit me
best. This project exposed areas I want to strengthen: writing reliable SQL,
testing transformations, documenting lineage, and explaining privacy and
quality trade-offs in plain language. Over the next six months, I can make
that goal practical by completing a focused SQL and data-modeling course,
building a small tested ETL project with a data dictionary, and reviewing a
privacy impact assessment with a lecturer or mentor. I should keep examples
of the work and ask for feedback rather than treat a certificate as proof of
competence. If this career direction does not match my actual interests, I
will revise it before submission; the plan is a starting point, not a claim
about experience or qualifications I have not described.

The standard I want to carry into future work is simple: separate what is
known from what is inferred, and make it possible for another person to check
the difference. Good data management is not just a clean table or a fast
pipeline. It is a set of choices that people can understand, challenge, and
correct. For SRG, success would mean that stores can keep serving customers,
analysts can explain the numbers they report, and customers are not made less
able to exercise choice just because the business has more data.

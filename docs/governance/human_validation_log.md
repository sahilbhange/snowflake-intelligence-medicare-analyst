# Human Validation Log

Use this log when comparing Cortex Analyst answers against known-good dashboard results before or after semantic model updates.

## Demo Validation Flow

1. Build one reference dashboard in Snowsight.
2. Run 5 test questions in Cortex Analyst.
3. Record expected vs actual behavior.
4. Mark each result as `pass`, `partial`, or `fail`.
5. Create follow-up actions for `partial` and `fail` items.

## Minimum Acceptance Target

- Simple questions: 80% pass rate
- Moderate questions: 65% pass rate

## Log Template

| Date | Model Version | Question ID | Question | Expected | Actual | Status | Action Needed |
|---|---|---|---|---|---|---|---|
| YYYY-MM-DD | vX.Y.Z | GQ01 | Top 5 states by claims | CA, TX, FL, NY, PA | CA, TX, FL, NY, PA | pass | no |

## Suggested Starter Questions

| ID | Complexity | Question |
|---|---|---|
| GQ01 | simple | Top 5 states by total claims |
| GQ02 | simple | Top 5 HCPCS codes by claims |
| GQ03 | simple | Total unique providers |
| GQ04 | moderate | Average Medicare payment for HCPCS E1390 |
| GQ05 | moderate | Rental vs non-rental claims |

## Weekly Review

1. Count pass/partial/fail results.
2. Group failures by root cause:
   - missing metric
   - missing synonym
   - ambiguous prompt
   - data/model mismatch
3. Apply semantic model updates.
4. Re-run only failed and partial questions.

## Action Register

| Action ID | Root Cause | Change | Owner | Status |
|---|---|---|---|---|
| A-001 | missing synonym | Add `rental` synonym to `supplier_rental_indicator` | owner_name | open |

## Useful SQL References

- [`sql/intelligence/validation_framework.sql`](../../sql/intelligence/validation_framework.sql)
- [`sql/intelligence/instrumentation.sql`](../../sql/intelligence/instrumentation.sql)
- [`sql/intelligence/semantic_model_tests.sql`](../../sql/intelligence/semantic_model_tests.sql)

## Related Docs

- [Semantic Model Lifecycle](semantic_model_lifecycle.md)
- [Semantic Model Publish Checklist](semantic_publish_checklist.md)
- [Metric Catalog](../reference/metric_catalog.md)

# Semantic Model Lifecycle

Use this guide when updating and publishing the semantic model so changes move safely from draft to production.

## Stages

`draft -> review -> published -> deprecated`

### Draft
- Update YAML, verified queries, and metric definitions.
- Run semantic regression tests.

### Review
- Validate high-value business questions in Snowsight.
- Confirm metric semantics against [Metric Catalog](../reference/metric_catalog.md).

### Published
- Upload model to `@ANALYTICS.CORTEX_SEM_MODEL_STG`.
- Confirm Cortex Analyst can answer baseline questions.

### Deprecated
- Replace with a newer published version.
- Keep rollback notes for one prior working version.

## Promotion Checklist

1. `make tests` passes.
2. 5 to 10 demo questions return expected behavior.
3. Publish checklist is complete.
4. Model is uploaded and source is active in Snowflake Intelligence.

## Versioning

Use `MAJOR.MINOR.PATCH`.

- `MAJOR`: breaking rename/removal.
- `MINOR`: added metrics, filters, or verified queries.
- `PATCH`: bug fix or non-breaking wording improvement.

## Related Docs

- [Publish Checklist](semantic_publish_checklist.md)
- [Metric Catalog](../reference/metric_catalog.md)
- [Execution Guide](../implementation/getting-started.md)
- [Human Validation Log](human_validation_log.md)

## Lifecycle Record

- Capture model version changes in PR descriptions or commit messages.

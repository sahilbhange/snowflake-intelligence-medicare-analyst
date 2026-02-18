# Semantic Model Publish Checklist

Use this checklist when publishing semantic model changes so you validate behavior before release and keep rollback simple.

## Demo Path

1. Run trust signals:
   - `make governance-demo`
2. Run regression tests:
   - `make tests`
3. Test 5 core prompts in Snowflake Intelligence:
   - top states by claims
   - top HCPCS by claims
   - payment for one HCPCS code
   - provider query by state
   - one hybrid question (definition + metric)
4. Upload model YAML to stage.
5. Confirm source is active in UI.

## Upload Command

```bash
snow sql -c sf_int -q "PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

## Release Checks

- [ ] `make tests` has no critical failures.
- [ ] Metric names and formulas align with [Metric Catalog](../reference/metric_catalog.md).
- [ ] Verified queries in YAML still execute.
- [ ] Cortex Analyst source loads the uploaded YAML.
- [ ] Search + Analyst routing still works for demo queries.

## Rollback

1. Re-upload previous known-good YAML.
2. Reload the Cortex Analyst source.
3. Re-run `make tests` and 3 smoke prompts.

## Notes

- Keep this checklist as the release source of truth for the public demo repo.

# Build Agent (Snowsight UI)

Use this if you want to create the same agent manually in Snowsight instead of running [`sql/agent/cortex_agent.sql`](cortex_agent.sql).

## Recommended Path

1. Run SQL path first for repeatable setup:
   - `make agent` (this creates semantic view first, then agent)
2. Use UI path only when you need to inspect or tweak tool config interactively.

## UI Quick Steps

1. Open Snowsight -> Cortex AI -> Agents -> Create.
2. Set object location to `MEDICARE_POS_DB.ANALYTICS`.
3. Add Cortex Analyst tool using:
   - `MEDICARE_POS_DB.ANALYTICS.DMEPOS_SEMANTIC_MODEL` (semantic view)
4. Add Cortex Search tools:
   - `MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC`
   - `MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC`
   - `MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC`
   - `MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC` (optional)
5. Copy orchestration/response rules from [`sql/agent/cortex_agent.sql`](cortex_agent.sql).
6. Save and test with 3 questions: search-only, analyst-only, hybrid.

## Validation Queries

```sql
show agents in schema MEDICARE_POS_DB.ANALYTICS;

show cortex search services in schema MEDICARE_POS_DB.SEARCH;
```

## Notes

- Keep SQL file as source of truth for repo reproducibility.
- If you update tool names in UI, sync them back to [`sql/agent/cortex_agent.sql`](cortex_agent.sql).

## Related

- [`docs/reference/cortex_agent_creation.md`](../../docs/reference/cortex_agent_creation.md)
- [`docs/reference/agent_guidance.md`](../../docs/reference/agent_guidance.md)
- [`sql/agent/cortex_agent.sql`](cortex_agent.sql)

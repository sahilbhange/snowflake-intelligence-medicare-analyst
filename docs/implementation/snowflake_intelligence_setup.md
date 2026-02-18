# Snowflake Intelligence Setup (Optional)

Use this guide only when wiring Cortex Analyst and Cortex Search sources in Snowsight and validating routing behavior.
If you are using the SQL-first flow (`make agent`), you can skip this guide.

## Prerequisites

- Deployment steps through `make search` are complete.
- Semantic model file is uploaded to `@MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG`.
- You can query `MEDICARE_POS_DB` with role `MEDICARE_POS_INTELLIGENCE`.

See [Execution Guide](getting-started.md) for full deployment order.

## Step 1: Add Cortex Analyst Source

1. Open Snowsight and go to AI and ML -> Agents.
2. Add source -> Cortex Analyst.
3. Choose one:
   - Upload [`models/DMEPOS_SEMANTIC_MODEL.yaml`](../../models/DMEPOS_SEMANTIC_MODEL.yaml) directly.
   - Use staged file from `ANALYTICS.CORTEX_SEM_MODEL_STG`.
4. Name it `Medicare DMEPOS Claims`.

Smoke test:

- `Top 5 states by total claims`

Expected: SQL generation + result table.

## Step 2: Add Cortex Search Sources

Add each service from `MEDICARE_POS_DB.SEARCH`:

1. `HCPCS_SEARCH_SVC`
2. `DEVICE_SEARCH_SVC`
3. `PROVIDER_SEARCH_SVC`

Recommended max results: `5`.

Smoke tests:

- `What is HCPCS E1390?`
- `Find oxygen concentrator devices`
- `Find endocrinologists in California`

## Step 3: Validate Routing

Run one prompt of each type:

- Analyst: `Top 10 states by claim volume`
- Search: `What is HCPCS E0431?`
- Hybrid: `What are oxygen concentrators and how much does Medicare spend on them?`

Expected behavior:

- Analyst prompts generate SQL.
- Search prompts use Cortex Search responses.
- Hybrid prompts combine search context and analytics.

## Step 4: Optional PDF Search Source

If `PDF_SEARCH_SVC` is created, add it as another Cortex Search source.

Reference setup:

- [Embedding Strategy](../reference/embedding_strategy.md)

## Permissions Snippets

```sql
GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC TO ROLE <consumer_role>;
GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC TO ROLE <consumer_role>;
GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.PROVIDER_SEARCH_SVC TO ROLE <consumer_role>;
GRANT READ ON STAGE ANALYTICS.CORTEX_SEM_MODEL_STG TO ROLE <consumer_role>;
```

## Troubleshooting

### Analyst shows no results

Checks:

- semantic YAML is uploaded and selected in source.
- YAML references objects that exist in `ANALYTICS`.
- role has `SELECT` on required tables/views.

### Search service not visible

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA SEARCH;
```

If missing, rerun:

```bash
make search
```

### Slow responses

```sql
ALTER WAREHOUSE MEDICARE_POS_WH RESUME;
SHOW WAREHOUSES LIKE 'MEDICARE_POS_WH';
```

## Done Criteria

- [ ] Analyst source active.
- [ ] Three search sources active.
- [ ] Analyst, Search, and Hybrid prompts succeed.

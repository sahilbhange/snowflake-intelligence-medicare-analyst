# AI Observability Governance

Use this folder when you want to turn raw Snowflake AI observability events into governance-ready analytics for the demo trust layer.

## What this achieves in the demo

Without this layer, AI activity is hard to review because one user question is split into many event rows with nested JSON.

With this layer, each question becomes one governed record you can audit:

- who asked
- which tools were used
- generated SQL
- latency and token usage
- estimated cost
- success/failure status

This is the operational backbone for trust-layer reporting, not just technical plumbing.

## Data flow

```
SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    -> GOVERNANCE.V_AI_GOVERNANCE_PARAMS
    -> GOVERNANCE.POPULATE_AI_GOVERNANCE()
    -> GOVERNANCE.AI_AGENT_GOVERNANCE
```

## Files and order

1. [`01_grant_all_privileges.sql`](01_grant_all_privileges.sql) (one-time bootstrap, ACCOUNTADMIN)
2. [`02_create_governance_objects.sql`](02_create_governance_objects.sql) (normal run, MEDICARE_POS_INTELLIGENCE)
3. [`03_create_scheduled_task.sql`](03_create_scheduled_task.sql) (normal run, MEDICARE_POS_INTELLIGENCE)
4. [`04_create_quality_tables.sql`](04_create_quality_tables.sql) (normal run, MEDICARE_POS_INTELLIGENCE)

Least-privilege note:
- `01_grant_all_privileges.sql` now uses `SECURITYADMIN` for project object grants.
- `ACCOUNTADMIN` is only used for account/system grants (`EXECUTE TASK`, `SNOWFLAKE.CORTEX_USER`, and `AI_OBSERVABILITY_EVENTS_LOOKUP`).

## Quick run

```bash
# one-time per environment
snow sql -c sf_int -f sql/observability/01_grant_all_privileges.sql

# normal runtime flow
snow sql -c sf_int -f sql/observability/02_create_governance_objects.sql
```

Optional:

```bash
snow sql -c sf_int -f sql/observability/03_create_scheduled_task.sql
snow sql -c sf_int -f sql/observability/04_create_quality_tables.sql
```

## Quick validation

```sql
-- 1) Raw question count
select count(*) from SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS;

-- 2) Flattened one-row-per-question view
select count(*) from GOVERNANCE.V_AI_GOVERNANCE_PARAMS;

-- 3) Final governance table
select count(*) from GOVERNANCE.AI_AGENT_GOVERNANCE;
```

## Common checks

- Missing privileges:
  rerun [`01_grant_all_privileges.sql`](01_grant_all_privileges.sql) as `ACCOUNTADMIN`.
- No rows in governance table:
  run `CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(7);`.
- Scheduled task not populating:
  check task state and warehouse status.

## Scope notes

- This folder handles observability ingestion and shaping.
- Business profiling and data-quality checks live in `sql/governance/`.

## Related docs

- [`docs/trust_layer/trust_layer_architecture.md`](../../docs/trust_layer/trust_layer_architecture.md) for the end-to-end trust-layer architecture and where observability fits.

# Cleanup Teardown

Use [`sql/cleanup/teardown.sql`](teardown.sql) to fully remove deployed Snowflake objects for this repo.

## What it deletes

- Agent: `DMEPOS_INTELLIGENCE_AGENT_SQL`
- Search services: HCPCS, Device, Provider, PDF
- Database objects under `MEDICARE_POS_DB`
- Warehouse: `MEDICARE_POS_WH`
- Roles: `MEDICARE_POS_ADMIN`, `MEDICARE_POS_INTELLIGENCE`

## What it does not delete

- Local repo files (`sql/`, `models/`, `docs/`, `data/`, `.private/`)

## Run

```bash
make teardown
```

Or directly:

```bash
snow sql -c sf_int -f sql/cleanup/teardown.sql
```

## Safety

- Script uses `IF EXISTS` so reruns are safe.
- Makefile target asks for confirmation before execution.

## Redeploy after teardown

```bash
make demo
# or
make deploy-all
```

## Related

- [`docs/implementation/getting-started.md`](../../docs/implementation/getting-started.md)
- [`sql/cleanup/teardown.sql`](teardown.sql)

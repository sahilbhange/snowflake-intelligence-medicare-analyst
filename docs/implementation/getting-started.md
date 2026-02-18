# Execution Guide

Use this runbook to deploy the full demo in the correct order and verify each stage.

## Prerequisites

- Snowflake account with Cortex features enabled (Preferably test Snowflake account)
- Snowflake CLI installed (`snow --version`).
- Python 3.10+ and `make` installed.
- Role with permission to create roles, warehouse, database, schemas, and search services.
- One-time admin access (or pre-granted observability permissions) to run `make observability-bootstrap`.

## One-time Snow CLI Setup

Makefile targets call `snow sql` and default to connection name `sf_int` from your Snow CLI connection config (`~/.snowflake/connections.toml`).

```bash
snow connection add sf_int
snow connection test -c sf_int
```

Connection smoke test:

```bash
snow sql -c sf_int -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()"
```

If your connection name is different, override it at runtime:

```bash
make SNOW_OPTS="sql -c <connection_name>" demo
```

## Project Flow

```text
data -> setup -> load -> transform -> search -> governance-demo -> instrumentation -> validation -> observability -> grants -> tests -> agent(optional)
```

## Recommended Commands

### Option A: Full chain

If this is a new environment, run one-time bootstrap first:

```bash
make observability-bootstrap
```

```bash
make demo
```

Then run:

```bash
make tests
```

### Option B: Step by step

```bash
make data
make setup
make load
make transform
make search
make governance-demo
make instrumentation
make validation
make observability
make grants
make tests
```

For a fresh environment, run this once before the sequence:

```bash
make observability-bootstrap
```

## Step Details

### 1) Download data

```bash
make data
```

Creates local source files used by ingestion scripts.

### 2) Create Snowflake infrastructure

```bash
make setup
```

Creates role, warehouse, database, schemas, and base stage.

Verify:

```sql
USE ROLE MEDICARE_POS_INTELLIGENCE;
SHOW SCHEMAS IN DATABASE MEDICARE_POS_DB;
```

### 3) Load raw data

```bash
make load
```

`make load` runs `make stage-raw` first, which uploads:
- `data/dmepos_referring_provider.json`
- `data/gudid_delimited/*.txt`

If those files are missing, run `make data` first.

Verify:

```sql
SELECT COUNT(*) AS raw_dmepos_rows FROM RAW.RAW_DMEPOS;
SELECT COUNT(*) AS raw_gudid_rows FROM RAW.RAW_GUDID_DEVICE;
```

### 4) Build curated and analytics model

```bash
make transform
```

Verify:

```sql
SELECT COUNT(*) FROM CURATED.DMEPOS_CLAIMS;
SELECT COUNT(*) FROM CURATED.GUDID_DEVICES;
SELECT COUNT(*) FROM ANALYTICS.FACT_DMEPOS_CLAIMS;
```

### 5) Create Cortex Search services

```bash
make search
```

This step now creates HCPCS/device/provider search plus PDF stage + PDF upload + PDF search service.
If local files exist in [`pdf/cms_manuals/`](../../pdf/cms_manuals/), they are uploaded automatically before PDF service creation.
It can take a few minutes because Snowflake initializes indexing in the background. Keep the run going and wait for completion.

Verify:

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA SEARCH;
```

### 6) Governance (demo-first)

```bash
make governance-demo
```

This creates a minimal trust layer for the Medium walkthrough.

Verify:

```sql
SELECT * FROM GOVERNANCE.SENSITIVITY_POLICY;
SELECT * FROM GOVERNANCE.DATA_PROFILE_RESULTS ORDER BY run_ts DESC LIMIT 20;
```

### 7) Create instrumentation and eval seed

```bash
make instrumentation
```

Verify:

```sql
SELECT COUNT(*) FROM INTELLIGENCE.ANALYST_EVAL_SET;
```

### 8) Validation framework

```bash
make validation
```

Verify:

```sql
SELECT COUNT(*) FROM INTELLIGENCE.BUSINESS_QUESTIONS;
```

### 9) Observability trust layer

```bash
# one-time bootstrap in a new environment
make observability-bootstrap

# build observability objects in normal runs
make observability
```

This is part of the standard trust-layer process. `make demo` runs `make observability` in the default path.

### 10) Apply grants

```bash
make grants
```

This applies post-deploy access for runtime roles and services.

### 11) Semantic tests

```bash
make tests
```

Verify:

```sql
SELECT result, COUNT(*)
FROM INTELLIGENCE.SEMANTIC_TEST_RESULTS
GROUP BY result
ORDER BY result;
```

## Optional: Semantic Model YAML Upload (Snowsight Path)

Use this only if you want to configure a Cortex Analyst source in Snowsight UI.
This is not required for the SQL-defined agent created by `make agent`.

Stage path:

`@MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG/DMEPOS_SEMANTIC_MODEL.yaml`

Upload command:

```bash
snow sql -c sf_int -q "PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

## Optional: Snowflake Intelligence UI Setup

After deployment and YAML upload, configure UI sources using:

- [Snowflake Intelligence Setup (Optional)](snowflake_intelligence_setup.md)

## Cortex Agent (included in demo)

`make agent` now builds semantic view + search services, then creates the agent:

```bash
make agent
```

Guide:

- [Cortex Agent Creation](../reference/cortex_agent_creation.md)

## Optional PDF Policy Search Refresh

```bash
make pdf-setup
# either upload in Snowsight, or use:
make pdf-upload
make search-pdf
make pdf-validate
```

Use this when you upload new PDFs and want to refresh only the PDF service without rerunning all search targets.

Reference:

- [Embedding Strategy](../reference/embedding_strategy.md)

## Common Issues

| Issue | Check | Fix |
|---|---|---|
| `Insufficient privileges` | active role | switch role and rerun setup/grants |
| `No data loaded` | stage upload paths | fix local `PUT` paths in ingestion SQL |
| `Search service missing` | services in `SEARCH` schema | rerun `make search` |
| `Agent creation fails` | semantic view + search services exist | rerun `make semantic-view`, `make search`, then `make agent` |
| `Tests failing` | model/object drift | rerun `make transform` then `make tests` |

## Related Docs

- [Data Model](data_model.md)
- [Metric Catalog](../reference/metric_catalog.md)
- [Semantic Model Publish Checklist](../governance/semantic_publish_checklist.md)

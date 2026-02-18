# Trust Layer Architecture

Use this reference to understand how observability, governance, and validation are wired into the repo and deployment flow.

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      USER INTERACTION                           │
│          "What are the top 5 states by claims?"                 │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                SNOWFLAKE INTELLIGENCE AGENT                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Cortex Agent │→ │   Semantic   │→ │ Cortex       │           │
│  │ (Planning)   │  │   Model      │  │ Analyst      │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS            │
│         (8+ spans per query, nested JSON)                       │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TRUST LAYER (3 PILLARS)                    │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │ AI OBSERVABILITY │  │ DATA GOVERNANCE  │  │  SEMANTIC    │   │
│  │                  │  │                  │  │  VALIDATION  │   │
│  │ • Agent metrics  │  │ • Metadata       │  │ • Human      │   │
│  │ • Token tracking │  │ • Lineage        │  │   feedback   │   │
│  │ • Cost analysis  │  │ • Data quality   │  │ • Eval seeds │   │
│  └──────────────────┘  └──────────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CONSUMPTION LAYER                            │
│  • Dashboards  • Cost reports  • Quality alerts  • Compliance   │
└─────────────────────────────────────────────────────────────────┘
```

## 3 Pillars

### 1. AI Observability ([`sql/observability/`](../../sql/observability/))

Monitor AI agent execution, track costs, measure performance.

**Key Objects:**
- `GOVERNANCE.AI_AGENT_GOVERNANCE` — Flattened governance records (1 row per query, 32 columns: identity, agent, tokens, cost, quality, timestamps)
- `GOVERNANCE.V_AI_GOVERNANCE_PARAMS` — Real-time view that parses AI_OBSERVABILITY_EVENTS spans
- `GOVERNANCE.POPULATE_AI_GOVERNANCE(LOOKBACK_DAYS)` — Batch insert from view into table (deduplicates by request_id)
- `GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH` — Daily scheduled task

**Files:**

| File | Purpose |
|------|---------|
| [`01_grant_all_privileges.sql`](../../sql/observability/01_grant_all_privileges.sql) | Grant AI Observability access |
| [`02_create_governance_objects.sql`](../../sql/observability/02_create_governance_objects.sql) | Primary governance infrastructure (table, view, proc) |
| [`03_create_scheduled_task.sql`](../../sql/observability/03_create_scheduled_task.sql) | Daily automation |
| [`04_create_quality_tables.sql`](../../sql/observability/04_create_quality_tables.sql) | Answer quality views and alerting tasks |

### 2. Data Governance ([`sql/governance/`](../../sql/governance/))

Metadata catalog, lineage tracking, data quality checks, drift detection.

**Key Objects:**
- `GOVERNANCE.COLUMN_METADATA` — Business definitions + sensitivity tags per column
- `GOVERNANCE.DATA_LINEAGE` — Upstream/downstream dependency tracking for impact analysis
- `GOVERNANCE.DATA_QUALITY_CHECKS` — Validation rules registry (check SQL + severity)
- `GOVERNANCE.DATA_QUALITY_RESULTS` — Check execution history
- `GOVERNANCE.DATA_PROFILE_RESULTS` — Daily profile snapshots (row count, null rate, distinct count) used for trend and drift review

**Files:**

| File | Purpose |
|------|---------|
| [`metadata_and_quality.sql`](../../sql/governance/metadata_and_quality.sql) | Primary governance infrastructure |
| [`run_profiling.sql`](../../sql/governance/run_profiling.sql) | Daily profiling automation |

### 3. Semantic Validation ([`sql/intelligence/`](../../sql/intelligence/))

Human-in-the-loop validation, eval seeds, feedback collection.

**Key Objects:**
- `INTELLIGENCE.BUSINESS_QUESTIONS` — Curated Q&A pairs with expected answers and complexity tags
- `INTELLIGENCE.SEMANTIC_FEEDBACK` — User satisfaction tracking (feedback type, priority, status)
- `INTELLIGENCE.ANALYST_EVAL_SET` — Golden questions for regression testing (category + expected SQL pattern)
- `INTELLIGENCE.SEMANTIC_TEST_RESULTS` — Nightly test execution history
- `INTELLIGENCE.AI_VALIDATION_RESULTS` — Human-reviewed AI answer quality and SQL-quality scoring

**Files:**

| File | Purpose |
|------|---------|
| [`validation_framework.sql`](../../sql/intelligence/validation_framework.sql) | Primary validation infrastructure |
| [`instrumentation.sql`](../../sql/intelligence/instrumentation.sql) | Query logging + eval set infrastructure |
| [`eval_seed.sql`](../../sql/intelligence/eval_seed.sql) | Golden question catalog |
| [`semantic_model_tests.sql`](../../sql/intelligence/semantic_model_tests.sql) | Test execution framework |

## Data Flow

### End-to-End Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ STEP 1: User Query                                              │
│ Input: "What are the top 5 states by total claims?"             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 2: Snowflake Intelligence Processing                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Cortex Agent                                             │   │
│  │ • Parse question                                         │   │
│  │ • Check semantic model cache                             │   │
│  │ • Generate orchestration plan                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Cortex Analyst                                           │   │
│  │ • Read semantic layer (semantic view; YAML as source)    │   │
│  │ • Generate SQL from natural language                     │   │
│  │ • Execute query on ANALYTICS tables                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                         │                                       │
│                         ▼                                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Response Generation                                      │   │
│  │ • Format results as table + chart                        │   │
│  │ • Add natural language summary                           │   │
│  │ • Return to user                                         │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 3: AI Observability Event Generation                       │
│                                                                 │
│ SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS receives 8+ spans:      │
│  • Span 1: record_root (user question, agent response)          │
│  • Span 2: ResponseGeneration (model, tokens, SQL)              │
│  • Span 3-8: Tool executions (Analyst, Chart, Search)           │
│                                                                 │
│ Each span = 1 row with nested JSON                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 4: View Flattening (V_AI_GOVERNANCE_PARAMS)                │
│                                                                 │
│ CTEs extract from different span types:                         │
│  • root_span CTE → question, response, status                   │
│  • planning_span CTE → model, tokens, SQL                       │
│  • tool_span CTE → tools used, tool types                       │
│  • conversation_messages CTE → parse full conversation          │
│                                                                 │
│ LEFT JOIN on trace_id → 1 complete row with all metrics         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 5: Persistent Storage (AI_AGENT_GOVERNANCE)                │
│                                                                 │
│ POPULATE_AI_GOVERNANCE(LOOKBACK_DAYS) stored proc:              │
│  • SELECT * FROM V_AI_GOVERNANCE_PARAMS                         │
│  • WHERE query_date >= DATEADD(day, -LOOKBACK_DAYS, ...)        │
│  • AND request_id NOT IN (existing records) -- dedup            │
│  • INSERT INTO AI_AGENT_GOVERNANCE                              │
│                                                                 │
│ Result: Fast queries on clean, denormalized table               │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│ STEP 6: Consumption                                             │
│                                                                 │
│  • Cost dashboards (by user, by day, by model)                  │
│  • Performance monitoring (slow queries, error rates)           │
│  • Quality alerts (drift, low pass rate, failures)              │
│  • Compliance audits (who asked what, when)                     │
└─────────────────────────────────────────────────────────────────┘
```

## Integration Points

### How the 3 Pillars Connect

```
USER ASKS QUESTION
        │
        ▼
┌───────────────────────┐
│ 1. AI OBSERVABILITY   │ ← Captures execution (trace_id, tokens, SQL)
└───────────┬───────────┘
            │
            ├──→ Stores in: GOVERNANCE.AI_AGENT_GOVERNANCE
            │
            ▼
┌───────────────────────┐
│ 2. DATA GOVERNANCE    │ ← Validates data quality
└───────────┬───────────┘
            │
            ├──→ Checks: SQL validity, table existence (COLUMN_METADATA),
            │    metric drift (PROFILE_RESULTS)
            │
            ▼
┌───────────────────────┐
│ 3. SEMANTIC VALIDATION│ ← Evaluates answer quality
└───────────┬───────────┘
            │
            ├──→ Compares: SQL vs expected pattern (EVAL_SET),
            │    answer vs expected summary, human feedback
            │
            ▼
┌───────────────────────┐
│ FEEDBACK LOOP         │
│ • Update semantic     │
│   model descriptions  │
│ • Add eval seed       │
│ • Fix data quality    │
│ • Improve prompts     │
└───────────────────────┘
```

## Quick Reference: Which Table Do I Query?

| Question | Table | Pillar |
|----------|-------|--------|
| How much did user X spend last week? | `GOVERNANCE.AI_AGENT_GOVERNANCE` | AI Observability |
| What does column referring_npi mean? | `GOVERNANCE.COLUMN_METADATA` | Data Governance |
| Which tables depend on DMEPOS_CLAIMS? | `GOVERNANCE.DATA_LINEAGE` | Data Governance |
| How did profile metrics change run-over-run? | `GOVERNANCE.DATA_PROFILE_RESULTS` | Data Governance |
| What's the eval pass rate? | `INTELLIGENCE.SEMANTIC_TEST_RESULTS` | Semantic Validation |
| Which questions have low ratings? | `INTELLIGENCE.SEMANTIC_FEEDBACK` | Semantic Validation |
| What are our golden regression questions? | `INTELLIGENCE.ANALYST_EVAL_SET` | Semantic Validation |

## Setup Sequence

### Initial Setup (One-time)

```bash
# Step 1: Grant privileges (ACCOUNTADMIN role)
snow sql -c sf_int -f sql/observability/01_grant_all_privileges.sql

# Step 2: Create AI Observability infrastructure
snow sql -c sf_int -f sql/observability/02_create_governance_objects.sql
snow sql -c sf_int -f sql/observability/04_create_quality_tables.sql

# Step 3: Create Data Governance infrastructure
snow sql -c sf_int -f sql/governance/metadata_and_quality.sql

# Step 4: Create Semantic Validation infrastructure
snow sql -c sf_int -f sql/intelligence/instrumentation.sql
snow sql -c sf_int -f sql/intelligence/validation_framework.sql
snow sql -c sf_int -f sql/intelligence/eval_seed.sql

# Step 5: (Optional) Enable daily automation
snow sql -c sf_int -f sql/observability/03_create_scheduled_task.sql
snow sql -c sf_int -f sql/governance/run_profiling.sql
```

### Daily Operations

```sql
-- Populate AI governance data (last 1 day)
CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(1);

-- Review open alerts
SELECT * FROM INTELLIGENCE.QUALITY_ALERTS
WHERE status = 'OPEN' ORDER BY severity DESC;
```

## File Index

| # | File | Purpose | Schema | Run As |
|---|------|---------|--------|--------|
| 1 | [`sql/observability/01_grant_all_privileges.sql`](../../sql/observability/01_grant_all_privileges.sql) | One-time observability bootstrap grants | SNOWFLAKE | ACCOUNTADMIN |
| 2 | [`sql/observability/02_create_governance_objects.sql`](../../sql/observability/02_create_governance_objects.sql) | AI governance table/view/proc | GOVERNANCE | MEDICARE_POS_INTELLIGENCE |
| 3 | [`sql/governance/metadata_and_quality.sql`](../../sql/governance/metadata_and_quality.sql) | Data governance tables | GOVERNANCE | MEDICARE_POS_INTELLIGENCE |
| 4 | [`sql/intelligence/validation_framework.sql`](../../sql/intelligence/validation_framework.sql) | Semantic validation tables | INTELLIGENCE | MEDICARE_POS_INTELLIGENCE |
| 5 | [`sql/intelligence/instrumentation.sql`](../../sql/intelligence/instrumentation.sql) | Eval-set + query instrumentation tables | INTELLIGENCE | MEDICARE_POS_INTELLIGENCE |
| 6 | [`sql/observability/04_create_quality_tables.sql`](../../sql/observability/04_create_quality_tables.sql) | Quality-alert tables and evaluation views | INTELLIGENCE | MEDICARE_POS_INTELLIGENCE |
| 7 | [`sql/observability/03_create_scheduled_task.sql`](../../sql/observability/03_create_scheduled_task.sql) | Daily AI governance refresh | GOVERNANCE | MEDICARE_POS_INTELLIGENCE |
| 8 | [`sql/governance/run_profiling.sql`](../../sql/governance/run_profiling.sql) | Daily data profiling | GOVERNANCE | MEDICARE_POS_INTELLIGENCE |

## Related Docs

| File | Purpose |
|------|---------|
| [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md) | Semantic model versioning guide |
| [Semantic Model Publish Checklist](../governance/semantic_publish_checklist.md) | Pre-deployment checklist |
| [`sql/observability/README.md`](../../sql/observability/README.md) | AI Observability setup guide |

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid identifier 'CACHE_WRITE_TOKENS'` | View not recreated after schema change | Rerun view definition from [`02_create_governance_objects.sql`](../../sql/observability/02_create_governance_objects.sql) |
| `Expression type mismatch ARRAY/VARCHAR` | Column order mismatch between view and table | Ensure view SELECT order matches table DDL |
| `Object does not exist: AI_OBSERVABILITY_EVENTS` | Missing bootstrap grant | Run [`01_grant_all_privileges.sql`](../../sql/observability/01_grant_all_privileges.sql) once as ACCOUNTADMIN |

## Performance Notes

- **V_AI_GOVERNANCE_PARAMS** — Real-time JSON parsing; slow for large date ranges. Use for verification/debugging.
- **AI_AGENT_GOVERNANCE** — Materialized table; fast, pre-computed. Use for analysis and dashboards.
- Consider archiving records older than 90 days from `AI_AGENT_GOVERNANCE`.

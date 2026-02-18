# Documentation

Use this folder to deploy the demo, validate results, and find the right reference quickly.

## Start Here

1. [Execution Guide](implementation/getting-started.md)
2. [Data Model](implementation/data_model.md)

Optional UI path:
- [Snowflake Intelligence Setup (Optional)](implementation/snowflake_intelligence_setup.md)

## Docs by Topic

### Implementation
- [Execution Guide](implementation/getting-started.md)
- [Data Model](implementation/data_model.md)
- [Snowflake Intelligence Setup (Optional)](implementation/snowflake_intelligence_setup.md)

### Reference
- [Metric Catalog](reference/metric_catalog.md)
- [Agent Guidance](reference/agent_guidance.md)
- [Cortex Agent Creation](reference/cortex_agent_creation.md)
- [Semantic View Guide](reference/semantic_view_guide.md)
- [Embedding Strategy](reference/embedding_strategy.md)
- [Semantic Model Guide](reference/semantic_model_guide.md)
- [Demo Queries](reference/demo_queries.md)

### Governance
- [Data Dictionary](governance/data_dictionary.md)
- [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md)
- [Semantic Model Publish Checklist](governance/semantic_publish_checklist.md)
- [Human Validation Log](governance/human_validation_log.md)

### Advanced
- [Trust Layer Architecture](trust_layer/trust_layer_architecture.md)

## Repo Map

### Core files
- [`README.md`](../README.md): project overview and quickstart.
- [`Makefile`](../Makefile): execution targets.
- [`Makefile.ps1`](../Makefile.ps1): Windows PowerShell equivalent runner for Makefile targets.
- [`models/DMEPOS_SEMANTIC_MODEL.yaml`](../models/DMEPOS_SEMANTIC_MODEL.yaml): semantic model source.
- [`models/DMEPOS_SEMANTIC_VIEW.sql`](../models/DMEPOS_SEMANTIC_VIEW.sql): UI-generated semantic view DDL.

### SQL folders
- [`sql/setup/`](../sql/setup/): roles, schemas, grants, optional PDF stage setup.
- [`sql/ingestion/`](../sql/ingestion/): raw data loading.
- [`sql/transform/`](../sql/transform/): curated tables and analytics views.
- [`sql/search/`](../sql/search/): Cortex Search services.
- [`sql/intelligence/`](../sql/intelligence/): instrumentation, validation, semantic tests.
- [`sql/governance/`](../sql/governance/): metadata and profiling.
- [`sql/observability/`](../sql/observability/): AI observability ingestion and governance shaping.
- [`sql/agent/`](../sql/agent/): Cortex Agent creation.

### Data and content
- [`data/`](../data/): source download scripts.
- Medium articles are published externally (see links below).
- [`pdf/`](../pdf/): local CMS policy PDFs for optional PDF search.

## Standard Run Flow

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

One-time environment bootstrap (admin role):

```bash
make observability-bootstrap
```

`make load` already runs `make stage-raw`. Use `make stage-raw` only when you want to re-upload files without loading.

Note: `make` defaults to Snowflake CLI connection `sf_int`. If needed, run with:
`make SNOW_OPTS="sql -c <your_connection_name>" demo`
`make observability-bootstrap` is a one-time admin step per environment (`ACCOUNTADMIN` or equivalent pre-granted privileges).

Note: `make search` may run for a few minutes while Cortex Search indexing initializes; let the run finish.
It now includes PDF stage prep, local PDF upload from [`pdf/cms_manuals/`](../pdf/cms_manuals/) (if present), and PDF search service creation in the same target.

If creating the Cortex Agent:

```bash
# creates semantic view + search services first, then creates the agent
make agent
```

Trust-layer observability is part of the standard path:

```bash
make observability-bootstrap   # one-time admin bootstrap
make observability
```

## Medium Series

- [Hub Article](https://medium.com/p/c95edd83402e)
- [Part 1: Context Engineering](https://medium.com/p/c95edd83402e)
- [Part 2: Data Architecture](https://medium.com/p/ccdd6700bad8)
- [Part 3: Trust Layer](https://medium.com/p/7665aebb624f)

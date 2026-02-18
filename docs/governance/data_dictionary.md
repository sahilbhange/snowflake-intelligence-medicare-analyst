# Data Dictionary

Use this dictionary when you need table and column meaning, classification, and to set quality expectations for the demo dataset.

## Scope

This project uses public CMS and FDA datasets. It does not include patient-level PHI.

## Source Data

| Source | Path / Endpoint | Grain | Refresh |
|---|---|---|---|
| CMS DMEPOS Referring Provider | [`data/dmepos_referring_provider_download.py`](../../data/dmepos_referring_provider_download.py) | Provider + HCPCS aggregate | Annual snapshot |
| FDA GUDID | [`data/data_download.sh`](../../data/data_download.sh) | Device identifier (DI) | Periodic bulk release |

## Schema Layout

| Schema | Purpose |
|---|---|
| `RAW` | Raw landed source data. |
| `CURATED` | Cleaned and typed base tables. |
| `ANALYTICS` | Reporting dimensions and fact view. |
| `SEARCH` | Search corpora and Cortex Search services. |
| `GOVERNANCE` | Metadata, sensitivity, profiling outputs. |
| `INTELLIGENCE` | Eval, logging, and validation tables. |
| `OBSERVABILITY` | Optional helper schema for low-level AI event parsing. |

## Key Tables and Views

### `RAW.RAW_DMEPOS`

- Purpose: raw CMS records in `VARIANT`.
- Key column: `raw_claim_record`.
- Downstream: `CURATED.DMEPOS_CLAIMS`.

### `RAW.RAW_GUDID_DEVICE`

- Purpose: raw FDA device attributes.
- Key columns: `primary_di`, `brand_name`, `company_name`, `device_description`.
- Downstream: `CURATED.GUDID_DEVICES`.

### `CURATED.DMEPOS_CLAIMS`

- Grain: one row per `referring_npi + hcpcs_code`.
- Key business columns:
  - `provider_state`, `provider_specialty_desc`, `hcpcs_code`, `hcpcs_description`
  - `total_supplier_claims`, `total_supplier_services`, `total_supplier_benes`
  - `avg_supplier_medicare_payment`, `avg_supplier_medicare_allowed`, `avg_supplier_submitted_charge`

### `CURATED.GUDID_DEVICES`

- Grain: one row per device record.
- Key columns:
  - `di_number`, `brand_name`, `company_name`, `device_description`
  - `device_publish_date`, `commercial_distribution_status`

### `ANALYTICS.DIM_PROVIDER`

- Purpose: provider dimension from curated claims.
- Key columns: `provider_npi`, `provider_state`, `provider_city`, `provider_specialty_desc`.

### `ANALYTICS.DIM_DEVICE`

- Purpose: device dimension from curated GUDID.
- Key columns: `di_number`, `brand_name`, `company_name`, `device_description`.

### `ANALYTICS.DIM_PRODUCT_CODE`

- Purpose: device product code lookup.
- Key columns: `primary_di`, `product_code`, `product_code_name`.

### `ANALYTICS.FACT_DMEPOS_CLAIMS`

- Purpose: analytics fact view joining claims with provider/device context.
- Key columns:
  - `referring_npi`, `hcpcs_code`, `provider_state`
  - `total_supplier_claims`, `total_supplier_services`, `total_supplier_benes`

## Governance Objects

### `GOVERNANCE.COLUMN_METADATA`

Stores business metadata by dataset/column.

### `GOVERNANCE.SENSITIVITY_POLICY`

View that classifies fields as `public`, `internal`, `confidential`, or `restricted`.

### `GOVERNANCE.DATA_PROFILE_RESULTS`

Stores profiling runs (row counts, null checks, column stats).

## Observability Objects (Advanced)

### `OBSERVABILITY` schema

Reserved for helper views over `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS` when you need raw span-level analysis.

### `GOVERNANCE.V_AI_GOVERNANCE_PARAMS`

Parses nested observability spans into queryable governance fields.

### `GOVERNANCE.AI_AGENT_GOVERNANCE`

Stores one governed record per agent request (question, SQL, tools, latency, tokens, status, cost).

## Data Classification

| Level | Meaning | Typical Columns |
|---|---|---|
| `public` | Public government-sourced values. | HCPCS codes, aggregate claim metrics |
| `internal` | Operational or identifiers used internally. | NPI, specialty mappings |
| `confidential` | Limited internal access only. | Role-dependent columns in metadata policy |
| `restricted` | Highest control class when used. | Not expected in this demo dataset |

## Minimal Quality Rules

- `hcpcs_code` should not be null in curated claims.
- `total_supplier_services >= total_supplier_claims` for valid aggregates.
- Payment fields should be non-negative.
- `provider_state` should be a valid US state code when present.

## Operational Commands

```bash
# Minimal governance flow used in the Medium series
make governance-demo

# Full governance templates
make metadata
make profile
```

## Related Files

- [`sql/transform/build_curated_model.sql`](../../sql/transform/build_curated_model.sql)
- [`sql/governance/metadata_demo.sql`](../../sql/governance/metadata_demo.sql)
- [`sql/governance/profile_demo.sql`](../../sql/governance/profile_demo.sql)
- [`sql/governance/metadata_and_quality.sql`](../../sql/governance/metadata_and_quality.sql)
- [`sql/observability/01_grant_all_privileges.sql`](../../sql/observability/01_grant_all_privileges.sql)
- [`sql/observability/02_create_governance_objects.sql`](../../sql/observability/02_create_governance_objects.sql)

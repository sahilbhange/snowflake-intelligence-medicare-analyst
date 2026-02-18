# Data Model Diagram

Use this guide when designing, validating, or explaining the medallion schemas and analytics views used by the demo.

## Schema Architecture (Medallion)

| Schema | Layer | Contents |
|--------|-------|----------|
| RAW | Bronze | RAW_DMEPOS, RAW_GUDID_DEVICE, RAW_GUDID_PRODUCT_CODES (+ other RAW.GUDID helper tables) |
| CURATED | Silver | DMEPOS_CLAIMS, GUDID_DEVICES |
| ANALYTICS | Gold | DIM_PROVIDER, DIM_DEVICE, DIM_PRODUCT_CODE, FACT_DMEPOS_CLAIMS |
| SEARCH | - | Cortex Search services |
| INTELLIGENCE | - | Eval sets, query logging, validation |
| GOVERNANCE | - | Metadata, lineage, quality checks |
| OBSERVABILITY | - | Optional helper views for AI event telemetry and span-level debugging |

## Entity Relationship Diagram

![DMEPOS data model ERD](../diagrams/datamodel.png)

## Table Details

### CURATED Layer (Silver)

| Table | Description | Source |
|-------|-------------|--------|
| `CURATED.DMEPOS_CLAIMS` | Curated claims at provider + HCPCS grain | RAW.RAW_DMEPOS |
| `CURATED.GUDID_DEVICES` | Curated device catalog | RAW.RAW_GUDID_DEVICE |

> **See SQL:** Implementation details in [build_curated_model.sql](../../sql/transform/build_curated_model.sql)

### ANALYTICS Layer (Gold)

| View | Description | Source |
|------|-------------|--------|
| `ANALYTICS.DIM_PROVIDER` | Provider dimension (distinct providers) | CURATED.DMEPOS_CLAIMS |
| `ANALYTICS.DIM_DEVICE` | Device dimension | CURATED.GUDID_DEVICES |
| `ANALYTICS.DIM_PRODUCT_CODE` | Product code dimension | RAW.RAW_GUDID_PRODUCT_CODES |
| `ANALYTICS.FACT_DMEPOS_CLAIMS` | Enriched fact view (joins provider + device) | CURATED.DMEPOS_CLAIMS |

> **See SQL:** Star schema fact and dimension queries in [build_curated_model.sql](../../sql/transform/build_curated_model.sql)

## Notes

- `DMEPOS_CLAIMS` is the curated claims table at provider + HCPCS grain.
- `DIM_PROVIDER` is derived from `DMEPOS_CLAIMS` (distinct providers).
- `DIM_DEVICE` is derived from `GUDID_DEVICES`.
- `DIM_PRODUCT_CODE` is derived from GUDID product code data.
- `FACT_DMEPOS_CLAIMS` is a view that selects `f.*` (all claim columns) and adds 2 enrichment fields (`provider_specialty_desc_ref`, `device_brand_name`).
- The `hcpcs_code -> di_number` join is a demo-friendly link, not a strict key match.

# Embedding Strategy

Use this guide when implementing retrieval, especially Cortex Search and optional PDF policy search for the demo.

## Decision

| Use case | Recommended approach |
|---|---|
| HCPCS definitions | Cortex Search |
| Device lookup | Cortex Search |
| Provider lookup | Cortex Search |
| CMS policy PDFs | Cortex Search on parsed PDF text |
| Custom vector tuning outside Snowflake | Manual embeddings (advanced only) |

## Implemented Search Services

- `SEARCH.HCPCS_SEARCH_SVC`
- `SEARCH.DEVICE_SEARCH_SVC`
- `SEARCH.PROVIDER_SEARCH_SVC`
- `SEARCH.PDF_SEARCH_SVC` (optional)

Core service creation SQL lives in [`sql/search/`](../../sql/search/).

## PDF Policy Search (Merged Guide)

### Source documents

- CMS Chapter 20 (DMEPOS):
  - `https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf`
- CMS Chapter 23 (Fee Schedule):
  - `https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c23.pdf`

### Step 1: Download PDFs locally

```bash
mkdir -p pdf/cms_manuals

curl -o pdf/cms_manuals/clm104c20_dmepos.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"

curl -o pdf/cms_manuals/clm104c23_fee_schedule.pdf \
  "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c23.pdf"
```

### Step 2: Create stage and upload

```bash
make pdf-setup
make pdf-upload
```

If you prefer manual upload instead of `make pdf-upload`, upload PDFs to `@SEARCH.PDF_STAGE` using Snowsight.

### Step 3: Create PDF search service

```bash
make search-pdf
```

Service definition is in [`sql/search/cortex_search_pdf.sql`](../../sql/search/cortex_search_pdf.sql).

Note: `make search` already runs PDF stage setup + PDF service creation as part of the main flow.

### Step 4: Validate retrieval

```bash
make pdf-validate
```

Manual query check:

```sql
SELECT file_name, pdf_text
FROM TABLE(
  SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS rental equipment billing rules', LIMIT => 5)
);
```

## Quality Checks

### Service health

```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA SEARCH;
```

### Retrieval sanity

```sql
SELECT * FROM TABLE(SEARCH.HCPCS_SEARCH_SVC!SEARCH('oxygen concentrator', LIMIT => 5));
SELECT * FROM TABLE(SEARCH.DEVICE_SEARCH_SVC!SEARCH('wheelchair mobility', LIMIT => 5));
SELECT * FROM TABLE(SEARCH.PROVIDER_SEARCH_SVC!SEARCH('endocrinologist california', LIMIT => 5));
```

## Refresh and Cost

- Service refresh is controlled by `TARGET_LAG` in each SQL definition.
- Compute cost is primarily warehouse refresh + query execution.
- Cortex Search handles indexing and retrieval infrastructure; no manual vector column maintenance is needed for the default flow.

## Advanced Manual Embeddings (Optional)

Use manual vectors only if you need non-standard retrieval logic or external vector-store integration. Keep that flow outside the core learning path.

## Related Files

- [`sql/search/cortex_search_hcpcs.sql`](../../sql/search/cortex_search_hcpcs.sql)
- [`sql/search/cortex_search_devices.sql`](../../sql/search/cortex_search_devices.sql)
- [`sql/search/cortex_search_providers.sql`](../../sql/search/cortex_search_providers.sql)
- [`sql/search/cortex_search_pdf.sql`](../../sql/search/cortex_search_pdf.sql)
- [`sql/setup/pdf_stage_setup.sql`](../../sql/setup/pdf_stage_setup.sql)
- [`sql/setup/pdf_search_validation.sql`](../../sql/setup/pdf_search_validation.sql)

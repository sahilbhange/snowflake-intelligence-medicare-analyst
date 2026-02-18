# Agent Guidance: Routing and Best Practices

Use this guide when tuning how questions route between Cortex Analyst and Cortex Search and when defining response guardrails.

## Available Tools

### 1. Cortex Analyst (Semantic Model/View)
**Purpose:** Natural language queries over structured data
**Model:** [`models/DMEPOS_SEMANTIC_MODEL.yaml`](../../models/DMEPOS_SEMANTIC_MODEL.yaml)
**Best for:** Aggregations, comparisons, filtering, metrics

### 2. Cortex Search Services
**Purpose:** Entity lookup and definition retrieval

| Service | Best For |
|---------|----------|
| `HCPCS_SEARCH_SVC` | HCPCS code definitions, procedure lookups |
| `DEVICE_SEARCH_SVC` | Medical device catalog, FDA GUDID data |
| `PROVIDER_SEARCH_SVC` | Provider directory, NPI lookups |

## Routing Rules

### Route to Cortex Analyst When:

| Signal | Example Question |
|--------|-----------------|
| Aggregation keywords | "total", "sum", "average", "count", "how many" |
| Comparison keywords | "compare", "vs", "versus", "difference between" |
| Ranking keywords | "top", "highest", "lowest", "most", "least" |
| Filtering keywords | "in California", "where", "only", "for state X" |
| Metric questions | "what is the payment", "claims volume" |

**Example Questions:**
- "What are the top 10 states by total claims?" -> **Analyst**
- "Compare rental vs purchase claims" -> **Analyst**
- "Average Medicare payment for E-codes" -> **Analyst**
- "How many providers are in Texas?" -> **Analyst**

### Route to Cortex Search When:

| Signal | Example Question |
|--------|-----------------|
| Definition requests | "what is", "define", "explain", "describe" |
| Entity lookups | "find", "search for", "look up", "tell me about" |
| Code lookups | "HCPCS E1390", "code A4253" |
| Device queries | "device with DI number", "manufacturer of" |

**Example Questions:**
- "What is HCPCS E1390?" -> **Search (HCPCS)**
- "Find oxygen concentrator devices" -> **Search (Device)**
- "Who is provider NPI 1234567890?" -> **Search (Provider)**

### Route to Both (Hybrid):

| Pattern | Approach |
|---------|----------|
| Definition + Metrics | Search for definition, then Analyst for metrics |
| Entity + Comparison | Search to identify entities, Analyst to compare |
| Policy + Metrics | Search PDF snippets, then Analyst for totals |

**Example:**
- "What is E1390 and how much does Medicare pay for it?"
  1. **Search:** Get E1390 definition (oxygen concentrator)
  2. **Analyst:** Get average Medicare payment for HCPCS E1390

**Example (PDF hybrid):**
- "What does CMS say about DMEPOS rentals and how many rental claims do we have?"
  1. **Search:** Retrieve policy snippet from `PDF_SEARCH_SVC`
  2. **Analyst:** Aggregate rental claims from `FACT_DMEPOS_CLAIMS`

## Recommended Filters

When building Analyst queries, consider these filters:

### Geographic Filters
- `top_states`: Focus on high-volume states (CA, TX, FL, NY, PA)
- `california_providers`: California-only analysis
- `texas_providers`: Texas-only analysis

### HCPCS Filters
- `durable_medical_equipment`: E-codes only (equipment)
- `common_hcpcs`: Frequently billed codes
- `exclude_null_hcpcs`: Remove incomplete records

### Behavioral Filters
- `rentals_only`: Rental equipment analysis
- `high_volume_providers`: Providers with >100 claims

## Common Pitfalls and Fallbacks

### Issue: Ambiguous Question
**Example:** "Show me the data"
**Fallback:** Ask for clarification
- "What specific data would you like? Options: provider summary, HCPCS analysis, geographic breakdown"

### Issue: Out of Scope
**Example:** "Show patient names"
**Fallback:** Explain limitation
- "Patient-level data is not available. This dataset contains aggregated claims at the provider + HCPCS level."

### Issue: Temporal Questions
**Example:** "Year-over-year growth"
**Fallback:** Explain limitation
- "This dataset is a single snapshot without temporal dimension. Year-over-year trends are not available."

### Issue: HCPCS-Device Mapping
**Example:** "Which devices are billed under E1390?"
**Fallback:** Explain limitation
- "Direct HCPCS-to-device mapping is a simplification in this demo. For precise mapping, consult CMS HCPCS documentation."

## Agent Hints Table

For programmatic agent guidance, query the hints table:

```sql
-- Example: Get hints for common query patterns
-- Note: hints are stored in the GOVERNANCE schema in this project.
SELECT * FROM GOVERNANCE.AGENT_HINTS
WHERE hint_category = 'geographic';
```

### Recommended Hints Structure:

| Category | Hint | Example |
|----------|------|---------|
| geographic | Use top_states filter for regional focus | `provider_state IN ('CA','TX','FL','NY','PA')` |
| hcpcs | E-codes are equipment | `hcpcs_code LIKE 'E%'` |
| payment | Round monetary values to 2 decimals | `ROUND(amount, 2)` |
| rental | Use supplier_rental_indicator | `= 'Y'` for rentals |

## Response Guidelines

### For Aggregation Results:
- Include row counts when relevant
- Round monetary values to 2 decimals
- Add context for unusual values

### For Comparisons:
- Show both values being compared
- Calculate percentage difference when meaningful
- Note any data quality caveats

### For Definitions (from Search):
- Include source attribution
- Note related codes or devices if relevant
- Suggest follow-up questions

## Error Handling

| Error Type | Recommended Response |
|------------|---------------------|
| No results | "No data found for [criteria]. Try broadening the filter." |
| Null values | "Some records have missing values for [field]." |
| Division by zero | Handle with NULLIF; explain if result is null |
| Query timeout | "Query taking too long. Try adding filters to reduce scope." |

## Guardrails

### Do Not:
- Return individual patient or beneficiary identifiers
- Make clinical recommendations
- Speculate about fraud without clear data support
- Provide time estimates for data availability

### Always:
- Cite the data source (CMS DMEPOS, FDA GUDID)
- Note known limitations
- Suggest related queries for deeper analysis
- Round financial figures appropriately

## Related Documentation

- [Metric Catalog](metric_catalog.md) - Metric definitions
- [Data Dictionary](../governance/data_dictionary.md) - Column definitions
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md) - Model versioning

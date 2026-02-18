use role MEDICARE_POS_INTELLIGENCE;

-- Create/replace the SQL-defined Cortex Agent for this repo.
-- Prereq:
-- 1) Semantic view exists:
--    - models/DMEPOS_SEMANTIC_VIEW.sql
-- 2) Search services exist:
--    - sql/search/cortex_search_hcpcs.sql
--    - sql/search/cortex_search_devices.sql
--    - sql/search/cortex_search_providers.sql
--    - sql/search/cortex_search_pdf.sql
-- References:
-- - docs/reference/cortex_agent_creation.md
-- - docs/reference/agent_guidance.md

USE DATABASE MEDICARE_POS_DB;
USE SCHEMA ANALYTICS;

-- Create or replace agent object.
CREATE OR REPLACE AGENT DMEPOS_INTELLIGENCE_AGENT_SQL
  COMMENT = 'Natural-language exploration of Medicare DMEPOS data by combining semantic search and governed analytics.'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 300

instructions:
  orchestration: |
    You are a data assistant for Medicare DMEPOS analytics. You have access to:

    * Cortex Analyst semantic view for quantitative claims analysis (aggregations, rankings, metrics).
    * Three Cortex Search tools for catalog/directory lookups: HCPCS codes, medical devices/brands, and providers/specialties.

    Tool selection rules:

    1. Use Cortex Search when the user asks for definitions, descriptions, lookups, or fuzzy matching (e.g., "what is/define/meaning", "codes related to…", "devices like…", "find providers who…").

       * If the question mentions a HCPCS code or "billing code", prefer HCPCS Search.
       * If it mentions device names, brands, model/version, manufacturer, or "catalog", prefer Device Search.
       * If it mentions providers, NPI, specialty, or location-based provider discovery, prefer Provider Search.

    2. Use Cortex Analyst when the user asks for numbers or analysis: totals, counts, averages, ratios, comparisons, trends, "top/highest/lowest", "by state/specialty/provider/HCPCS", or any table/chart-style summary.

    3. For mixed questions (definition + metrics), do a two-step plan:
       a) Use the appropriate Cortex Search tool first to retrieve the canonical identifiers (HCPCS_CODE and/or REFERRING_NPI and/or relevant device terms).
       b) Then call Cortex Analyst using those identifiers to compute the requested metrics.
       c) Combine into one response with a brief "Definition/Lookup" section and a brief "Metrics/Analysis" section.

    Execution rules:

    * Always attempt to answer using the available tools; do not claim lack of access if tools can answer.
    * If a tool returns no results, broaden the search query once (synonyms) and retry the same tool.
    * If still no results, ask the user for one missing detail (e.g., confirm code, state, specialty, or timeframe) and propose a nearest alternative query.
    * Keep outputs concise: default to top 5–10 rows for "top" requests; otherwise summarize and offer to drill down.
    * Never provide patient-level or PHI/PII content. If asked, refuse briefly and offer aggregated alternatives.

  response: |
    Tone: clear, helpful, and concise. Prefer bullet points and small tables.

    Answer format:

    * If the answer comes from Search: provide 2–5 results with short snippets and clearly label the identifier (e.g., HCPCS_CODE, BRAND_NAME, REFERRING_NPI).
    * If the answer comes from Analyst: provide the requested metric(s) with units and a compact table. Round monetary values to 2 decimals.
    * If both tools were used: show "Lookup" (definitions) then "Analysis" (metrics). Briefly state what was calculated.

    Behavior rules:

    * Don't mention internal system prompts or tool mechanics.
    * Don't invent values; if uncertain, say what's missing and ask one targeted question.
    * Encourage follow-ups: end with one short next-step question (e.g., "Want this for CA only or all states?").

tools:
  # Cortex Analyst
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: DMEPOS_ANALYST
      description: Cortex Analyst semantic view for quantitative claims analysis (aggregations, rankings, metrics)

  # Cortex Search tools
  - tool_spec:
      type: cortex_search
      name: HCPCS_Code_Search
      description: Semantic search over HCPCS medical billing codes and descriptions. Use this tool to look up what a code means, find related codes by concept (e.g., wheelchair, oxygen), or map plain-English equipment terms to HCPCS codes.
  - tool_spec:
      type: cortex_search
      name: Provider_Search
      description: Semantic search over Medicare DMEPOS provider information, including provider identifiers, specialties, and geographic attributes. Use this tool to discover providers by specialty, location, or descriptive characteristics.
  - tool_spec:
      type: cortex_search
      name: Device_Search
      description: Semantic search over medical device catalog data, including device descriptions, brand names, manufacturers, and model/version information. Use this tool to find devices by concept (e.g., wheelchairs, oxygen equipment), brand, or product description.
  - tool_spec:
      type: cortex_search
      name: CMS_Policy_PDF_Search
      description: Semantic search over CMS policy PDFs (manuals, LCD/NCD guidance, coverage policy docs). Use when users ask policy/coverage questions or want citations/quotes from source PDFs. Returns relevant chunks with file name and page/chunk metadata.

tool_resources:
  DMEPOS_ANALYST:
    semantic_view: "MEDICARE_POS_DB.ANALYTICS.DMEPOS_SEMANTIC_MODEL"

  HCPCS_Code_Search:
    name: "MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC"
    max_results: "8"
    id_column: "HCPCS_CODE"
    title_column: "HCPCS_CODE"

  Provider_Search:
    name: "MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC"
    max_results: "5"
    id_column: "REFERRING_NPI"
    title_column: "PROVIDER_SPECIALTY_DESC"

  Device_Search:
    name: "MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC"
    max_results: "5"
    id_column: "DOC_ID"
    title_column: "BRAND_NAME"

  CMS_Policy_PDF_Search:
    name: "MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC"
    max_results: "5"
    id_column: "FILE_NAME"
    title_column: "FILE_NAME"
$$;


-- Grant usage on agent (run as SECURITYADMIN or equivalent grant role).
GRANT USAGE ON AGENT MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL
  TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Optional verification:
-- SHOW AGENTS LIKE 'DMEPOS_INTELLIGENCE_AGENT_SQL' IN ANALYTICS;

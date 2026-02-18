-- Apply post-deployment grants for search services, analytics objects, and agent setup.
-- Run after setup + transform + search scripts.
-- Execution flow: docs/implementation/getting-started.md
-- Agent details: docs/reference/cortex_agent_creation.md

use role SECURITYADMIN;

-- ============================================================================
-- CORTEX FUNCTION ACCESS GRANTS
-- ============================================================================
-- Needed for Cortex text-splitting functions (SPLIT_TEXT*, etc.).
-- Note: Use IMPORTED PRIVILEGES for SNOWFLAKE system database access.

grant imported privileges on database SNOWFLAKE
  to role MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- CORTEX SEARCH SERVICE GRANTS
-- ============================================================================
-- Grant usage on Cortex Search services (run after sql/search/*.sql)

grant usage on cortex search service MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC
  to role MEDICARE_POS_INTELLIGENCE;

grant usage on cortex search service MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC
  to role MEDICARE_POS_INTELLIGENCE;

grant usage on cortex search service MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC
  to role MEDICARE_POS_INTELLIGENCE;

-- PDF Search service (run after sql/search/cortex_search_pdf.sql)
-- grant usage on cortex search service MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC
--   to role MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- ANALYTICS VIEWS GRANTS
-- ============================================================================
-- Explicit grants on analytics views (run after sql/transform/build_curated_model.sql)

grant select on view MEDICARE_POS_DB.ANALYTICS.DIM_PROVIDER
  to role MEDICARE_POS_INTELLIGENCE;

grant select on view MEDICARE_POS_DB.ANALYTICS.DIM_DEVICE
  to role MEDICARE_POS_INTELLIGENCE;

grant select on view MEDICARE_POS_DB.ANALYTICS.DIM_PRODUCT_CODE
  to role MEDICARE_POS_INTELLIGENCE;

grant select on view MEDICARE_POS_DB.ANALYTICS.FACT_DMEPOS_CLAIMS
  to role MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- CURATED TABLES GRANTS
-- ============================================================================
-- Explicit grants on curated tables

grant select on table MEDICARE_POS_DB.CURATED.DMEPOS_CLAIMS
  to role MEDICARE_POS_INTELLIGENCE;

grant select on table MEDICARE_POS_DB.CURATED.GUDID_DEVICES
  to role MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- CORTEX ANALYST & AGENT GRANTS
-- ============================================================================
-- Uncomment if your account supports these features

-- Grant permission to create agents in ANALYTICS schema
grant create agent on schema MEDICARE_POS_DB.ANALYTICS
  to role MEDICARE_POS_INTELLIGENCE;

-- Grant permission to create semantic view in ANALYTICS schema
grant create semantic view on schema MEDICARE_POS_DB.ANALYTICS
  to role MEDICARE_POS_INTELLIGENCE;

-- Grant access to semantic model stage
grant read, write on stage MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG
  to role MEDICARE_POS_INTELLIGENCE;

-- Grant usage on agent (run after agent is created)
-- grant usage on agent MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL
--   to role MEDICARE_POS_INTELLIGENCE;

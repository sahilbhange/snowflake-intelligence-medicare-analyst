-- Bootstrap core Snowflake objects for this repo.
-- Run first in setup flow. Requires SECURITYADMIN and SYSADMIN.
-- Setup guide: docs/implementation/getting-started.md
-- Architecture context: docs/implementation/data_model.md

set target_user = '<username>';

-- 1) Create role (SECURITYADMIN)
use role SECURITYADMIN;
create role if not exists MEDICARE_POS_INTELLIGENCE;

grant role MEDICARE_POS_INTELLIGENCE to role SYSADMIN;

-- 2) Create warehouse, database, schemas (SYSADMIN)
use role SYSADMIN;

create warehouse if not exists MEDICARE_POS_WH
  with warehouse_size = 'XSMALL'
  auto_suspend = 300
  auto_resume = true
  initially_suspended = true;

create database if not exists MEDICARE_POS_DB
  comment = 'Medicare POS analytics demo database';

-- Medallion architecture schemas
create schema if not exists MEDICARE_POS_DB.RAW
  comment = 'Bronze layer: raw landing tables and stages';

create schema if not exists MEDICARE_POS_DB.CURATED
  comment = 'Silver layer: cleaned and typed tables';

create schema if not exists MEDICARE_POS_DB.ANALYTICS
  comment = 'Gold layer: dimension and fact views for analytics';

-- Semantic model stage (used for Cortex Analyst / Agent workflows).
-- Keeping it here avoids "grant on missing stage" errors later in `sql/setup/apply_grants.sql`.
create stage if not exists MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG
  comment = 'Stage for Cortex Analyst semantic model YAML files';

create schema if not exists MEDICARE_POS_DB.SEARCH
  comment = 'Cortex Search document tables and services';

create schema if not exists MEDICARE_POS_DB.INTELLIGENCE
  comment = 'Snowflake Intelligence: eval sets, logging, validation';

create schema if not exists MEDICARE_POS_DB.GOVERNANCE
  comment = 'Metadata, lineage, data quality, agent hints';

create schema if not exists MEDICARE_POS_DB.OBSERVABILITY
  comment = 'AI Observability helper views over SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS';

-- 3) Grant baseline access (SECURITYADMIN)
use role SECURITYADMIN;

grant usage on database MEDICARE_POS_DB to role MEDICARE_POS_INTELLIGENCE;

-- RAW schema grants
grant usage on schema MEDICARE_POS_DB.RAW to role MEDICARE_POS_INTELLIGENCE;
grant select on all tables in schema MEDICARE_POS_DB.RAW to role MEDICARE_POS_INTELLIGENCE;
grant select on future tables in schema MEDICARE_POS_DB.RAW to role MEDICARE_POS_INTELLIGENCE;
grant create table, create stage, create file format on schema MEDICARE_POS_DB.RAW to role MEDICARE_POS_INTELLIGENCE;

-- CURATED schema grants
grant usage on schema MEDICARE_POS_DB.CURATED to role MEDICARE_POS_INTELLIGENCE;
grant select on all tables in schema MEDICARE_POS_DB.CURATED to role MEDICARE_POS_INTELLIGENCE;
grant select on future tables in schema MEDICARE_POS_DB.CURATED to role MEDICARE_POS_INTELLIGENCE;
grant create table on schema MEDICARE_POS_DB.CURATED to role MEDICARE_POS_INTELLIGENCE;

-- ANALYTICS schema grants
grant usage on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on all tables in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on future tables in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on all views in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on future views in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant create table, create view, create stage on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant create semantic view on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

-- SEARCH schema grants
grant usage on schema MEDICARE_POS_DB.SEARCH to role MEDICARE_POS_INTELLIGENCE;
grant select on all tables in schema MEDICARE_POS_DB.SEARCH to role MEDICARE_POS_INTELLIGENCE;
grant select on future tables in schema MEDICARE_POS_DB.SEARCH to role MEDICARE_POS_INTELLIGENCE;
grant create table, create cortex search service on schema MEDICARE_POS_DB.SEARCH to role MEDICARE_POS_INTELLIGENCE;
grant create stage, create file format on schema MEDICARE_POS_DB.SEARCH to role MEDICARE_POS_INTELLIGENCE;


-- INTELLIGENCE schema grants (includes DML for logging/eval)
grant usage on schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;
grant select, insert, update, delete on all tables in schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;
grant select, insert, update, delete on future tables in schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;
grant select on all views in schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;
grant select on future views in schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;
grant create table, create view on schema MEDICARE_POS_DB.INTELLIGENCE to role MEDICARE_POS_INTELLIGENCE;

-- GOVERNANCE schema grants (includes DML for quality results)
grant usage on schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;
grant select, insert, update, delete on all tables in schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;
grant select, insert, update, delete on future tables in schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;
grant select on all views in schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;
grant select on future views in schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;
grant create table, create view on schema MEDICARE_POS_DB.GOVERNANCE to role MEDICARE_POS_INTELLIGENCE;

-- OBSERVABILITY schema grants (views over Snowflake AI Observability events)
grant usage on schema MEDICARE_POS_DB.OBSERVABILITY to role MEDICARE_POS_INTELLIGENCE;
grant select on all views in schema MEDICARE_POS_DB.OBSERVABILITY to role MEDICARE_POS_INTELLIGENCE;
grant select on future views in schema MEDICARE_POS_DB.OBSERVABILITY to role MEDICARE_POS_INTELLIGENCE;
grant create view on schema MEDICARE_POS_DB.OBSERVABILITY to role MEDICARE_POS_INTELLIGENCE;

-- Warehouse grants
grant usage, operate on warehouse MEDICARE_POS_WH to role MEDICARE_POS_INTELLIGENCE;

-- 4) Bind user defaults (SECURITYADMIN) (Optional)
-- Make sure target_user is set to an existing user.

alter user identifier($target_user)
  set default_role = MEDICARE_POS_INTELLIGENCE,
      default_warehouse = MEDICARE_POS_WH,
      default_namespace = MEDICARE_POS_DB.ANALYTICS;

grant role MEDICARE_POS_INTELLIGENCE to user identifier($target_user);

-- Create Cortex Search service for HCPCS definitions.
-- Prereq: `ANALYTICS.FACT_DMEPOS_CLAIMS` is populated (`make transform`).
-- Reference: docs/reference/embedding_strategy.md
-- Agent wiring: docs/reference/cortex_agent_creation.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- 1) Build the HCPCS search corpus
create or replace table SEARCH.HCPCS_SEARCH_DOCS as
select distinct
  hcpcs_code as doc_id,
  'hcpcs_definition' as doc_type,
  concat('HCPCS ', hcpcs_code, ': ', hcpcs_description) as title,
  concat(
    'Code: ', hcpcs_code, '. ',
    'Description: ', hcpcs_description, '. ',
    'Category: ', case
      when hcpcs_code like 'E%' then 'Durable Medical Equipment (DME)'
      when hcpcs_code like 'A%' then 'Medical/Surgical Supplies'
      when hcpcs_code like 'L%' then 'Orthotic/Prosthetic Procedures'
      else 'Other'
    end, '. ',
    'Rental indicator: ', case
      when supplier_rental_indicator = 'Y' then 'Available for rental'
      else 'Purchase only'
    end
  ) as body,
  hcpcs_code,
  hcpcs_description,
  rbcs_id,
  supplier_rental_indicator
from ANALYTICS.FACT_DMEPOS_CLAIMS
where hcpcs_code is not null
  and hcpcs_description is not null;

-- 2) Create the Cortex Search service
create or replace cortex search service SEARCH.HCPCS_SEARCH_SVC
  on body
  attributes doc_id, doc_type, hcpcs_code, hcpcs_description, rbcs_id
  warehouse = MEDICARE_POS_WH
  target_lag = '7 day'
as (
  select
    body,
    doc_id,
    doc_type,
    hcpcs_code,
    hcpcs_description,
    rbcs_id
  from SEARCH.HCPCS_SEARCH_DOCS
);

-- 3) Optional access grant
-- grant usage on cortex search service MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC
--   to role MEDICARE_POS_INTELLIGENCE;

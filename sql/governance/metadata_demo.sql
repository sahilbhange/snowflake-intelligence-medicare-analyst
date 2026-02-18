-- Lightweight governance demo: column metadata + sensitivity policy view.
-- Use this for quick walkthroughs and screenshots.
-- Full setup lives in `sql/governance/metadata_and_quality.sql`.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- Core demo table.
create or replace table GOVERNANCE.COLUMN_METADATA (
  dataset_name string,
  column_name string,
  data_type string,
  business_definition string,
  allowed_values string,
  sensitivity string,
  example_value string,
  created_at timestamp_ntz default current_timestamp(),
  updated_at timestamp_ntz default current_timestamp()
);

-- Seed a small set of columns for demo narration.
insert into GOVERNANCE.COLUMN_METADATA (
  dataset_name, column_name, data_type, business_definition, allowed_values, sensitivity, example_value
) values
  -- Provider identifiers (treat as internal in this demo)
  ('DIM_PROVIDER', 'referring_npi', 'number', 'National Provider Identifier for the referring provider.', '10-digit numeric', 'internal', '1003000126'),
  ('DIM_PROVIDER', 'provider_name', 'string', 'Display name for the referring provider.', 'text', 'internal', 'Jane Smith MD'),

  -- Geo attributes (safe to group by in screenshots)
  ('DIM_PROVIDER', 'provider_state', 'string', 'Two-letter US state code for provider location.', 'US state codes', 'public', 'CA'),
  ('DIM_PROVIDER', 'provider_city', 'string', 'Provider city.', 'text', 'public', 'LOS ANGELES'),

  -- Claims identifiers and measures
  ('FACT_DMEPOS_CLAIMS', 'hcpcs_code', 'string', 'HCPCS code at provider + HCPCS grain.', 'A*, E*, L*', 'public', 'E1390'),
  ('FACT_DMEPOS_CLAIMS', 'total_supplier_claims', 'number', 'Total claim count for the provider + HCPCS combination.', '>= 0', 'public', '150'),
  ('FACT_DMEPOS_CLAIMS', 'avg_supplier_medicare_payment', 'number', 'Average Medicare payment amount (USD).', '>= 0', 'confidential', '68.20');

-- Convert sensitivity tags into handling guidance.
create or replace view GOVERNANCE.SENSITIVITY_POLICY as
select
  dataset_name as table_name,
  column_name,
  sensitivity as sensitivity_level,
  case sensitivity
    when 'public' then 'Safe to share externally'
    when 'internal' then 'Internal use only'
    when 'confidential' then 'Aggregate before sharing'
    when 'restricted' then 'Explicit approval required'
  end as handling_instructions,
  business_definition
from GOVERNANCE.COLUMN_METADATA
where sensitivity is not null;

-- Optional row-count check.
select 'COLUMN_METADATA' as table_name, count(*) as row_cnt from GOVERNANCE.COLUMN_METADATA
union all
select 'SENSITIVITY_POLICY', count(*) from GOVERNANCE.SENSITIVITY_POLICY;

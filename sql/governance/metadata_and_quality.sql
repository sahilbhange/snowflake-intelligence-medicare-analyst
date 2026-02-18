-- Create governance metadata, lineage, quality checks, and agent hint tables.
-- Use this script for the fuller governance setup (demo scripts are smaller subsets).
-- References:
-- - docs/governance/data_dictionary.md
-- - docs/governance/semantic_publish_checklist.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- 1) Dataset-level metadata
create or replace table GOVERNANCE.DATASET_METADATA (
  dataset_name string,
  description string,
  grain string,
  source_system string,
  refresh_frequency string,
  freshness_sla_hours number,
  owner string,
  quality_score number(5,2),
  governance_notes string,
  created_at timestamp_ntz default current_timestamp(),
  updated_at timestamp_ntz default current_timestamp()
);

-- 2) Column-level metadata
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

-- 3) Lineage registry
create or replace table GOVERNANCE.DATA_LINEAGE (
  dataset_name string,
  upstream_source string,
  transformation_script string,
  notes string,
  created_at timestamp_ntz default current_timestamp()
);

-- 4) Data quality checks and results
create or replace table GOVERNANCE.DATA_QUALITY_CHECKS (
  check_id string,
  table_name string,
  check_name string,
  check_description string,
  check_sql string,
  severity string,
  owner string,
  created_at timestamp_ntz default current_timestamp()
);

create or replace table GOVERNANCE.DATA_QUALITY_RESULTS (
  check_id string,
  run_id string,
  run_ts timestamp_ntz default current_timestamp(),
  status string,
  metric_value number,
  expected_threshold string,
  notes string
);

-- 5) Seed dataset metadata (example entries)
insert into GOVERNANCE.DATASET_METADATA (
  dataset_name,
  description,
  grain,
  source_system,
  refresh_frequency,
  freshness_sla_hours,
  owner,
  quality_score,
  governance_notes
) values
  (
    'DMEPOS_CLAIMS',
    'Curated DMEPOS claims at provider + HCPCS grain.',
    'referring_npi + hcpcs_code',
    'CMS DMEPOS Referring Provider',
    'ad hoc',
    168,
    'data-engineering',
    0.95,
    'Public data; no patient-level fields.'
  ),
  (
    'GUDID_DEVICES',
    'Curated FDA device catalog entries keyed by DI.',
    'di_number',
    'FDA GUDID',
    'monthly',
    720,
    'data-engineering',
    0.93,
    'Public data; manufacturer metadata only.'
  ),
  (
    'FACT_DMEPOS_CLAIMS',
    'Analytics-ready view over claims and dimensions.',
    'referring_npi + hcpcs_code',
    'Derived',
    'ad hoc',
    168,
    'analytics',
    0.95,
    'Joins provider and device dims for enrichment.'
  );

-- 6) Seed column metadata (example entries)
insert into GOVERNANCE.COLUMN_METADATA (
  dataset_name,
  column_name,
  data_type,
  business_definition,
  allowed_values,
  sensitivity,
  example_value
) values
  (
    'DMEPOS_CLAIMS',
    'hcpcs_code',
    'string',
    'Healthcare Common Procedure Coding System code.',
    'A*, E*, L*',
    'public',
    'E1390'
  ),
  (
    'DMEPOS_CLAIMS',
    'supplier_rental_indicator',
    'string',
    'Flag indicating rental eligibility for the HCPCS code.',
    'Y, N',
    'public',
    'Y'
  ),
  (
    'GUDID_DEVICES',
    'di_number',
    'string',
    'Device Identifier (DI) from GUDID.',
    'unique',
    'public',
    '00627595000712'
  );

-- 7) Seed lineage entries
insert into GOVERNANCE.DATA_LINEAGE (
  dataset_name,
  upstream_source,
  transformation_script,
  notes
) values
  (
    'DMEPOS_CLAIMS',
    'RAW.RAW_DMEPOS',
    'sql/transform/build_curated_model.sql',
    'Parsed JSON fields into typed columns.'
  ),
  (
    'GUDID_DEVICES',
    'RAW.RAW_GUDID_DEVICE',
    'sql/transform/build_curated_model.sql',
    'Standardized device attributes and dates.'
  ),
  (
    'FACT_DMEPOS_CLAIMS',
    'CURATED.DMEPOS_CLAIMS + ANALYTICS.DIM_PROVIDER + ANALYTICS.DIM_DEVICE',
    'sql/transform/build_curated_model.sql',
    'Left joins for enrichment.'
  );

-- 8) Seed quality checks (examples)
insert into GOVERNANCE.DATA_QUALITY_CHECKS (
  check_id,
  table_name,
  check_name,
  check_description,
  check_sql,
  severity,
  owner
) values
  (
    'DQ01',
    'CURATED.DMEPOS_CLAIMS',
    'non_null_hcpcs',
    'HCPCS codes should not be null.',
    'select count(*) from CURATED.DMEPOS_CLAIMS where hcpcs_code is null',
    'high',
    'data-engineering'
  ),
  (
    'DQ02',
    'CURATED.DMEPOS_CLAIMS',
    'non_null_referring_npi',
    'Referring NPI should not be null.',
    'select count(*) from CURATED.DMEPOS_CLAIMS where referring_npi is null',
    'high',
    'data-engineering'
  ),
  (
    'DQ03',
    'CURATED.GUDID_DEVICES',
    'unique_di',
    'Device identifiers should be unique.',
    'select count(*) from (select di_number, count(*) as cnt from CURATED.GUDID_DEVICES group by di_number having count(*) > 1)',
    'medium',
    'data-engineering'
  );

-- 9) Optional: run checks manually and insert results
-- insert into GOVERNANCE.DATA_QUALITY_RESULTS (check_id, run_id, status, metric_value, expected_threshold, notes)
-- values ('DQ01', 'manual-run-001', 'pass', 0, '= 0', 'HCPCS null check');

-- 10) Additional column metadata with sensitivity tags
insert into GOVERNANCE.COLUMN_METADATA (
  dataset_name, column_name, data_type, business_definition, allowed_values, sensitivity, example_value
) values
  -- Provider identifiers
  ('DMEPOS_CLAIMS', 'referring_npi', 'number', 'National Provider Identifier for the referring provider. Unique 10-digit identifier assigned by CMS.', 'numeric 10-digit', 'internal', '1234567890'),
  ('DIM_PROVIDER', 'referring_npi', 'number', 'National Provider Identifier for the referring provider.', 'numeric 10-digit', 'internal', '1234567890'),
  ('DIM_PROVIDER', 'provider_name', 'string', 'Full name of the referring provider (first + last).', 'text', 'internal', 'John Smith MD'),
  ('DIM_PROVIDER', 'provider_first_name', 'string', 'First name of the referring provider.', 'text', 'internal', 'John'),
  ('DIM_PROVIDER', 'provider_last_name', 'string', 'Last name of the referring provider.', 'text', 'internal', 'Smith'),
  ('DIM_PROVIDER', 'provider_specialty_desc', 'string', 'Medical specialty description.', 'text', 'public', 'Internal Medicine'),
  ('DIM_PROVIDER', 'provider_specialty_code', 'string', 'CMS specialty code.', 'alphanumeric', 'public', '11'),

  -- Geographic fields
  ('DIM_PROVIDER', 'provider_state', 'string', 'Two-letter state code where provider is located.', 'US state codes', 'public', 'CA'),
  ('DIM_PROVIDER', 'provider_city', 'string', 'City where provider is located.', 'text', 'public', 'Los Angeles'),
  ('DIM_PROVIDER', 'provider_zip', 'string', 'ZIP code where provider is located. May reveal approximate location.', 'numeric 5-digit', 'internal', '90210'),
  ('DIM_PROVIDER', 'provider_country', 'string', 'Country code (typically US).', 'country codes', 'public', 'US'),

  -- HCPCS fields
  ('DMEPOS_CLAIMS', 'hcpcs_description', 'string', 'Human-readable description of the HCPCS code.', 'text', 'public', 'Oxygen concentrator, single delivery port'),
  ('DMEPOS_CLAIMS', 'rbcs_id', 'string', 'RBCS (BETOS) category identifier for grouping codes.', 'alphanumeric', 'public', 'DC002N'),

  -- Volume metrics
  ('DMEPOS_CLAIMS', 'total_supplier_claims', 'number', 'Total count of supplier claims for this provider-HCPCS combination.', 'positive integer', 'public', '150'),
  ('DMEPOS_CLAIMS', 'total_supplier_services', 'number', 'Total count of services rendered.', 'positive integer', 'public', '200'),
  ('DMEPOS_CLAIMS', 'total_supplier_benes', 'number', 'Count of distinct Medicare beneficiaries served for this provider-HCPCS combination (may be suppressed for small cells).', 'positive integer', 'internal', '75'),
  ('DMEPOS_CLAIMS', 'total_suppliers', 'number', 'Total count of suppliers involved.', 'positive integer', 'public', '5'),

  -- Payment metrics
  ('DMEPOS_CLAIMS', 'avg_supplier_medicare_payment', 'number', 'Average Medicare payment amount per service. Financial data.', 'positive decimal', 'confidential', '125.50'),
  ('DMEPOS_CLAIMS', 'avg_supplier_medicare_allowed', 'number', 'Average Medicare allowed amount per service.', 'positive decimal', 'confidential', '150.00'),
  ('DMEPOS_CLAIMS', 'avg_supplier_submitted_charge', 'number', 'Average charge submitted by supplier before Medicare processing.', 'positive decimal', 'confidential', '200.00'),
  ('DMEPOS_CLAIMS', 'avg_supplier_medicare_standard', 'number', 'Average Medicare standard amount.', 'positive decimal', 'confidential', '145.00');

-- 11) Agent hints table

create or replace table GOVERNANCE.AGENT_HINTS (
  hint_id string default uuid_string(),
  hint_category string,           -- 'geographic', 'hcpcs', 'payment', 'rental', 'query_pattern'
  hint_name string,
  hint_description string,
  hint_sql_fragment string,
  use_when string,                -- When to apply this hint
  priority number default 5,      -- 1 = highest priority
  created_at timestamp_ntz default current_timestamp()
);

insert into GOVERNANCE.AGENT_HINTS (hint_category, hint_name, hint_description, hint_sql_fragment, use_when, priority)
values
  -- Geographic hints
  ('geographic', 'top_states_filter', 'Focus on high-volume states for meaningful analysis',
   'provider_state IN (''CA'', ''TX'', ''FL'', ''NY'', ''PA'')',
   'When user asks about regional trends without specifying states', 3),

  ('geographic', 'exclude_null_state', 'Exclude records with null state for geographic analysis',
   'provider_state IS NOT NULL',
   'When grouping by state', 2),

  -- HCPCS hints
  ('hcpcs', 'dme_equipment_filter', 'E-codes represent durable medical equipment',
   'hcpcs_code LIKE ''E%''',
   'When user asks about equipment or DME', 3),

  ('hcpcs', 'exclude_null_hcpcs', 'Exclude records with null HCPCS for code-level analysis',
   'hcpcs_code IS NOT NULL',
   'When grouping by HCPCS code', 2),

  ('hcpcs', 'common_codes', 'Focus on frequently occurring codes for representative analysis',
   'hcpcs_code IN (''A4239'', ''E1390'', ''E0431'', ''E1392'', ''E0601'')',
   'When demonstrating common patterns', 4),

  -- Payment hints
  ('payment', 'round_monetary', 'Round monetary values to 2 decimal places',
   'ROUND(amount, 2)',
   'Always for monetary display', 1),

  ('payment', 'nullif_division', 'Protect against division by zero in ratios',
   'NULLIF(denominator, 0)',
   'When calculating ratios', 1),

  -- Rental hints
  ('rental', 'rentals_only', 'Filter for rental equipment analysis',
   'supplier_rental_indicator = ''Y''',
   'When user asks about rentals', 3),

  ('rental', 'purchases_only', 'Filter for purchased equipment analysis',
   'supplier_rental_indicator = ''N''',
   'When user asks about purchases', 3),

  -- Query pattern hints
  ('query_pattern', 'top_n_pattern', 'Standard pattern for top-N queries',
   'ORDER BY metric DESC LIMIT 10',
   'When user asks for top or highest', 2),

  ('query_pattern', 'provider_join', 'Join pattern for provider dimension',
   'JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi',
   'When needing provider attributes like state or specialty', 2);

-- 12) Sensitivity policy view

create or replace view GOVERNANCE.SENSITIVITY_POLICY as
select
    dataset_name as table_name,
    column_name,
    sensitivity as sensitivity_level,
    case sensitivity
        when 'public' then 'No restrictions - safe for external sharing'
        when 'internal' then 'Internal use only - no external sharing without approval'
        when 'confidential' then 'Aggregation required - do not expose individual records'
        when 'restricted' then 'Explicit approval required for any use'
    end as handling_instructions,
    business_definition
from GOVERNANCE.COLUMN_METADATA
where sensitivity is not null;

-- Verification row counts

select 'DATASET_METADATA' as table_name, count(*) as row_cnt from GOVERNANCE.DATASET_METADATA
union all
select 'COLUMN_METADATA', count(*) from GOVERNANCE.COLUMN_METADATA
union all
select 'DATA_LINEAGE', count(*) from GOVERNANCE.DATA_LINEAGE
union all
select 'DATA_QUALITY_CHECKS', count(*) from GOVERNANCE.DATA_QUALITY_CHECKS
union all
select 'AGENT_HINTS', count(*) from GOVERNANCE.AGENT_HINTS;

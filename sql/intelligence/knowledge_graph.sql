-- Build a minimal knowledge graph (entities + relationships) for provider and HCPCS context.
-- Keep this lean; it is meant for demo-grade enrichment, not full ontology modeling.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema INTELLIGENCE;

-- Entity catalog
create or replace table INTELLIGENCE.KG_ENTITIES (
  entity_id string,
  entity_type string,        -- 'provider', 'hcpcs', 'specialty', 'state'
  entity_name string,
  properties variant,
  created_at timestamp_ntz default current_timestamp()
);

-- Relationship catalog
create or replace table INTELLIGENCE.KG_RELATIONSHIPS (
  relationship_id string default uuid_string(),
  source_entity_id string,
  target_entity_id string,
  relationship_type string,  -- 'bills_for', 'located_in', 'specializes_in'
  properties variant,
  created_at timestamp_ntz default current_timestamp()
);

-- Seed provider entities
insert into INTELLIGENCE.KG_ENTITIES (entity_id, entity_type, entity_name, properties)
select distinct
  'provider:' || referring_npi as entity_id,
  'provider' as entity_type,
  concat_ws(' ', provider_first_name, provider_last_name) as entity_name,
  object_construct(
    'npi', referring_npi,
    'specialty', provider_specialty_desc,
    'city', provider_city,
    'state', provider_state
  ) as properties
from ANALYTICS.DIM_PROVIDER
where referring_npi is not null;

-- Seed HCPCS entities
insert into INTELLIGENCE.KG_ENTITIES (entity_id, entity_type, entity_name, properties)
select distinct
  'hcpcs:' || hcpcs_code as entity_id,
  'hcpcs' as entity_type,
  hcpcs_description as entity_name,
  object_construct(
    'code', hcpcs_code,
    'rbcs_id', rbcs_id
  ) as properties
from ANALYTICS.FACT_DMEPOS_CLAIMS
where hcpcs_code is not null;

-- Provider bills for HCPCS
insert into INTELLIGENCE.KG_RELATIONSHIPS (source_entity_id, target_entity_id, relationship_type, properties)
select
  'provider:' || referring_npi as source_entity_id,
  'hcpcs:' || hcpcs_code as target_entity_id,
  'bills_for' as relationship_type,
  object_construct(
    'total_claims', sum(total_supplier_claims),
    'total_services', sum(total_supplier_services)
  ) as properties
from ANALYTICS.FACT_DMEPOS_CLAIMS
where referring_npi is not null
  and hcpcs_code is not null
group by referring_npi, hcpcs_code;

-- Provider located in state
insert into INTELLIGENCE.KG_RELATIONSHIPS (source_entity_id, target_entity_id, relationship_type, properties)
select distinct
  'provider:' || referring_npi as source_entity_id,
  'state:' || provider_state as target_entity_id,
  'located_in' as relationship_type,
  object_construct('state', provider_state) as properties
from ANALYTICS.DIM_PROVIDER
where referring_npi is not null
  and provider_state is not null;

-- Seed state entities
insert into INTELLIGENCE.KG_ENTITIES (entity_id, entity_type, entity_name, properties)
select distinct
  'state:' || provider_state as entity_id,
  'state' as entity_type,
  provider_state as entity_name,
  object_construct('state', provider_state) as properties
from ANALYTICS.DIM_PROVIDER
where provider_state is not null;

-- Verification counts
select 'KG_ENTITIES' as table_name, count(*) as row_cnt from INTELLIGENCE.KG_ENTITIES
union all
select 'KG_RELATIONSHIPS', count(*) from INTELLIGENCE.KG_RELATIONSHIPS;

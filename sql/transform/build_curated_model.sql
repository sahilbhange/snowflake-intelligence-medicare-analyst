-- Build curated tables and analytics views from RAW layer inputs.
-- Prereq: `sql/ingestion/load_raw_data.sql` has completed successfully.
-- Reference: docs/implementation/data_model.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;

-- Curated layer (Silver)

use schema CURATED;

-- 1) Curated claims table
create or replace table CURATED.DMEPOS_CLAIMS (
  referring_npi number,
  provider_last_name string,
  provider_first_name string,
  provider_city string,
  provider_state string,
  provider_zip string,
  provider_country string,
  provider_specialty_code string,
  provider_specialty_desc string,
  provider_specialty_source string,
  rbcs_level string,
  rbcs_id string,
  rbcs_desc string,
  hcpcs_code string,
  hcpcs_description string,
  supplier_rental_indicator string,
  total_suppliers number,
  total_supplier_benes number,
  total_supplier_claims number,
  total_supplier_services number,
  avg_supplier_submitted_charge number(38,4),
  avg_supplier_medicare_allowed number(38,4),
  avg_supplier_medicare_payment number(38,4),
  avg_supplier_medicare_standard number(38,4)
);

insert overwrite into CURATED.DMEPOS_CLAIMS
select
  try_to_number(raw_claim_record:"Rfrg_NPI"::string) as referring_npi,
  raw_claim_record:"Rfrg_Prvdr_Last_Name_Org"::string as provider_last_name,
  raw_claim_record:"Rfrg_Prvdr_First_Name"::string as provider_first_name,
  raw_claim_record:"Rfrg_Prvdr_City"::string as provider_city,
  raw_claim_record:"Rfrg_Prvdr_State_Abrvtn"::string as provider_state,
  raw_claim_record:"Rfrg_Prvdr_Zip5"::string as provider_zip,
  raw_claim_record:"Rfrg_Prvdr_Cntry"::string as provider_country,
  raw_claim_record:"Rfrg_Prvdr_Spclty_Cd"::string as provider_specialty_code,
  raw_claim_record:"Rfrg_Prvdr_Spclty_Desc"::string as provider_specialty_desc,
  raw_claim_record:"Rfrg_Prvdr_Spclty_Srce"::string as provider_specialty_source,
  raw_claim_record:"RBCS_Lvl"::string as rbcs_level,
  raw_claim_record:"RBCS_Id"::string as rbcs_id,
  raw_claim_record:"RBCS_Desc"::string as rbcs_desc,
  raw_claim_record:"HCPCS_CD"::string as hcpcs_code,
  raw_claim_record:"HCPCS_Desc"::string as hcpcs_description,
  raw_claim_record:"Suplr_Rentl_Ind"::string as supplier_rental_indicator,
  try_to_number(raw_claim_record:"Tot_Suplrs"::string) as total_suppliers,
  try_to_number(raw_claim_record:"Tot_Suplr_Benes"::string) as total_supplier_benes,
  try_to_number(raw_claim_record:"Tot_Suplr_Clms"::string) as total_supplier_claims,
  try_to_number(raw_claim_record:"Tot_Suplr_Srvcs"::string) as total_supplier_services,
  try_to_decimal(raw_claim_record:"Avg_Suplr_Sbmtd_Chrg"::string, 38, 4) as avg_supplier_submitted_charge,
  try_to_decimal(raw_claim_record:"Avg_Suplr_Mdcr_Alowd_Amt"::string, 38, 4) as avg_supplier_medicare_allowed,
  try_to_decimal(raw_claim_record:"Avg_Suplr_Mdcr_Pymt_Amt"::string, 38, 4) as avg_supplier_medicare_payment,
  try_to_decimal(raw_claim_record:"Avg_Suplr_Mdcr_Stdzd_Amt"::string, 38, 4) as avg_supplier_medicare_standard
from RAW.RAW_DMEPOS;

-- 2) Curated device table
create or replace table CURATED.GUDID_DEVICES (
  public_device_record_key string,
  public_version_status string,
  public_version_number number,
  di_number string,
  device_name string,
  brand_name string,
  version_or_model_number string,
  catalog_number string,
  company_name string,
  device_description string,
  device_status string,
  device_publish_date date,
  commercial_distribution_status string
);

insert overwrite into CURATED.GUDID_DEVICES
select
  public_device_record_key,
  public_version_status,
  try_to_number(public_version_number),
  primary_di as di_number,
  brand_name as device_name,
  brand_name,
  version_model_number,
  catalog_number,
  company_name,
  device_description,
  device_record_status as device_status,
  try_to_date(device_publish_date),
  device_comm_distribution_status
from RAW.RAW_GUDID_DEVICE;

-- Analytics layer (Gold)

use schema ANALYTICS;

-- 3) Analytics views
create or replace view ANALYTICS.DIM_PROVIDER as
select distinct
  referring_npi,
  provider_last_name,
  provider_first_name,
  provider_city,
  provider_state,
  provider_zip,
  provider_country,
  provider_specialty_code,
  provider_specialty_desc,
  provider_specialty_source
from CURATED.DMEPOS_CLAIMS
where referring_npi is not null;

create or replace view ANALYTICS.DIM_DEVICE as
select distinct
  di_number,
  public_device_record_key,
  public_version_status,
  public_version_number,
  brand_name,
  version_or_model_number,
  catalog_number,
  company_name,
  device_description,
  device_status,
  device_publish_date,
  commercial_distribution_status
from CURATED.GUDID_DEVICES;

create or replace view ANALYTICS.DIM_PRODUCT_CODE as
select distinct
  primary_di,
  product_code,
  product_code_name
from RAW.RAW_GUDID_PRODUCT_CODES
where product_code is not null;

create or replace view ANALYTICS.FACT_DMEPOS_CLAIMS as
select
  f.*,
  p.provider_specialty_desc as provider_specialty_desc_ref,
  d.brand_name as device_brand_name
from CURATED.DMEPOS_CLAIMS f
  left join ANALYTICS.DIM_PROVIDER p
    on f.referring_npi = p.referring_npi
  left join ANALYTICS.DIM_DEVICE d
    on f.hcpcs_code = d.di_number;

-- Optional checks
-- select count(*) from CURATED.DMEPOS_CLAIMS;
-- select count(*) from CURATED.GUDID_DEVICES;

-- select * from ANALYTICS.DIM_DEVICE limit 10;
select count(*) from ANALYTICS.FACT_DMEPOS_CLAIMS limit 100;

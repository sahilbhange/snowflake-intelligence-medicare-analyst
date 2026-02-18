-- Load CMS/FDA raw files into RAW landing tables.
-- Prereq: run data download scripts and upload files to RAW stages.
-- Reference: docs/implementation/getting-started.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema RAW;

-- 1) File formats
create or replace file format RAW.FF_CSV_STD
  type = csv
  field_delimiter = ','
  skip_header = 1
  field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL', 'null');

create or replace file format RAW.FF_JSON_STD
  type = json
  strip_outer_array = true;

create or replace file format RAW.FF_PIPE_STD
  type = csv
  field_delimiter = '|'
  skip_header = 1
  field_optionally_enclosed_by = '"'
  null_if = ('', 'NULL', 'null')
  error_on_column_count_mismatch = false;

-- 2) Internal stages
-- Keep `if not exists` so reruns do not wipe already uploaded files.
create stage if not exists RAW.RAW_DMEPOS_STAGE file_format = RAW.FF_CSV_STD;
create stage if not exists RAW.RAW_GUDID_STAGE file_format = RAW.FF_CSV_STD;

-- 3) Upload files
-- Preferred: `make stage-raw`
-- Manual fallback:
-- PUT 'file://data/dmepos_referring_provider.json' @RAW.RAW_DMEPOS_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
-- PUT 'file://data/gudid_delimited/*.txt' @RAW.RAW_GUDID_STAGE AUTO_COMPRESS=TRUE OVERWRITE=TRUE;

-- 4) Raw landing tables
-- Use an explicit payload column name for readability in downstream transforms.
create or replace table RAW.RAW_DMEPOS (raw_claim_record variant);

copy into RAW.RAW_DMEPOS
  from @RAW.RAW_DMEPOS_STAGE
  file_format = (format_name = RAW.FF_JSON_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_DEVICE (
  primary_di string,
  public_device_record_key string,
  public_version_status string,
  device_record_status string,
  public_version_number number,
  public_version_date string,
  device_publish_date string,
  device_comm_distribution_end_date string,
  device_comm_distribution_status string,
  brand_name string,
  version_model_number string,
  catalog_number string,
  duns_number string,
  company_name string,
  device_count string,
  device_description string,
  dm_exempt string,
  premarket_exempt string,
  device_hctp string,
  device_kit string,
  device_combination_product string,
  single_use string,
  lot_batch string,
  serial_number string,
  manufacturing_date string,
  expiration_date string,
  donation_id_number string,
  labeled_contains_nrl string,
  labeled_no_nrl string,
  mri_safety_status string,
  rx string,
  otc string,
  device_sterile string,
  sterilization_prior_to_use string
);

copy into RAW.RAW_GUDID_DEVICE
  from @RAW.RAW_GUDID_STAGE/device.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_IDENTIFIERS (
  primary_di string,
  device_id string,
  device_id_type string,
  device_id_issuing_agency string,
  contains_di_number string,
  pkg_quantity string,
  pkg_discontinue_date string,
  pkg_status string,
  pkg_type string
);

copy into RAW.RAW_GUDID_IDENTIFIERS
  from @RAW.RAW_GUDID_STAGE/identifiers.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_CONTACTS (
  primary_di string,
  phone string,
  phone_extension string,
  email string
);

copy into RAW.RAW_GUDID_CONTACTS
  from @RAW.RAW_GUDID_STAGE/contacts.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_PRODUCT_CODES (
  primary_di string,
  product_code string,
  product_code_name string
);

copy into RAW.RAW_GUDID_PRODUCT_CODES
  from @RAW.RAW_GUDID_STAGE/productCodes.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_DEVICE_SIZES (
  primary_di string,
  size_type string,
  size_unit string,
  size_value string,
  size_text string
);

copy into RAW.RAW_GUDID_DEVICE_SIZES
  from @RAW.RAW_GUDID_STAGE/deviceSizes.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_ENVIRONMENTAL_CONDITIONS (
  primary_di string,
  storage_handling_type string,
  storage_handling_high_unit string,
  storage_handling_high_value string,
  storage_handling_low_unit string,
  storage_handling_low_value string,
  storage_handling_special_condition_text string
);

copy into RAW.RAW_GUDID_ENVIRONMENTAL_CONDITIONS
  from @RAW.RAW_GUDID_STAGE/environmentalConditions.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_PREMARKET_SUBMISSIONS (
  primary_di string,
  submission_number string,
  supplement_number string
);

copy into RAW.RAW_GUDID_PREMARKET_SUBMISSIONS
  from @RAW.RAW_GUDID_STAGE/premarketSubmissions.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_GMDN_TERMS (
  primary_di string,
  gmdn_pt_name string,
  gmdn_pt_definition string,
  gmdn_code string,
  gmdn_code_status string,
  implantable string
);

copy into RAW.RAW_GUDID_GMDN_TERMS
  from @RAW.RAW_GUDID_STAGE/gmdnTerms.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

create or replace table RAW.RAW_GUDID_STERILIZATION_METHODS (
  primary_di string,
  sterilization_method string
);

copy into RAW.RAW_GUDID_STERILIZATION_METHODS
  from @RAW.RAW_GUDID_STAGE/sterilizationMethodTypes.txt.gz
  file_format = (format_name = RAW.FF_PIPE_STD)
  on_error = 'ABORT_STATEMENT';

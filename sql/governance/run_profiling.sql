-- Nightly profiling runner used by governance automation.
-- Writes row_count, null_rate, and distinct_count metrics to GOVERNANCE.DATA_PROFILE_RESULTS.
-- Keep demos/read-only checks in `sql/governance/profile_demo.sql` and `sql/governance/metadata_demo.sql`.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- Ensure results table exists for repeated runs.
create table if not exists GOVERNANCE.DATA_PROFILE_RESULTS (
  run_id string,
  run_ts timestamp_ntz default current_timestamp(),
  dataset_name string,
  column_name string,
  metric_name string,
  metric_value number(38,6),
  notes string
);

set run_id = (select uuid_string());
select $run_id;

-- Table-level row counts
insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'RAW.RAW_DMEPOS', null, 'row_count', count(*), 'Raw CMS JSON rows'
from RAW.RAW_DMEPOS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'RAW.RAW_GUDID_DEVICE', null, 'row_count', count(*), 'Raw GUDID device rows'
from RAW.RAW_GUDID_DEVICE;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'CURATED.DMEPOS_CLAIMS', null, 'row_count', count(*), 'Curated claims rows'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'CURATED.GUDID_DEVICES', null, 'row_count', count(*), 'Curated device rows'
from CURATED.GUDID_DEVICES;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'ANALYTICS.DIM_PROVIDER', null, 'row_count', count(*), 'Provider dimension rows'
from ANALYTICS.DIM_PROVIDER;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'ANALYTICS.FACT_DMEPOS_CLAIMS', null, 'row_count', count(*), 'Fact view rows'
from ANALYTICS.FACT_DMEPOS_CLAIMS;

-- Null-rate checks for key columns
insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.DMEPOS_CLAIMS',
  'hcpcs_code',
  'null_rate',
  round(count_if(hcpcs_code is null) / nullif(count(*), 0), 6),
  'Expect near zero'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.DMEPOS_CLAIMS',
  'referring_npi',
  'null_rate',
  round(count_if(referring_npi is null) / nullif(count(*), 0), 6),
  'Expect near zero'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.GUDID_DEVICES',
  'di_number',
  'null_rate',
  round(count_if(di_number is null) / nullif(count(*), 0), 6),
  'Device identifiers should be present'
from CURATED.GUDID_DEVICES;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'ANALYTICS.DIM_PROVIDER',
  'provider_state',
  'null_rate',
  round(count_if(provider_state is null) / nullif(count(*), 0), 6),
  'Nulls expected for some providers'
from ANALYTICS.DIM_PROVIDER;

-- Distinct counts for key identifiers
insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.DMEPOS_CLAIMS',
  'hcpcs_code',
  'distinct_count',
  count(distinct hcpcs_code),
  'Distinct billing codes'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'ANALYTICS.DIM_PROVIDER',
  'referring_npi',
  'distinct_count',
  count(distinct referring_npi),
  'Distinct providers'
from ANALYTICS.DIM_PROVIDER;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.GUDID_DEVICES',
  'di_number',
  'distinct_count',
  count(distinct di_number),
  'Distinct device identifiers'
from CURATED.GUDID_DEVICES;

-- Latest run summary
select *
from GOVERNANCE.DATA_PROFILE_RESULTS
where run_id = $run_id
order by dataset_name, metric_name, column_name;

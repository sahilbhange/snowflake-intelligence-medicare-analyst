-- Lightweight profiling demo (single-run checks).
-- Use this for manual governance walkthroughs; nightly runner is `sql/governance/run_profiling.sql`.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- Append-only results table for comparing repeated runs.
create table if not exists GOVERNANCE.DATA_PROFILE_RESULTS (
  run_id string,
  run_ts timestamp_ntz default current_timestamp(),
  dataset_name string,
  column_name string,
  metric_name string,
  metric_value number(38,6),
  notes string
);

-- Use SELECT form for broader Snowflake compatibility across clients.
set run_id = (select uuid_string());

-- Row counts (curated + analytics)
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
select $run_id, current_timestamp(), 'ANALYTICS.FACT_DMEPOS_CLAIMS', null, 'row_count', count(*), 'Fact rows'
from ANALYTICS.FACT_DMEPOS_CLAIMS;

-- Null-rate checks for selected columns
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
  'ANALYTICS.DIM_PROVIDER',
  'provider_state',
  'null_rate',
  round(count_if(provider_state is null) / nullif(count(*), 0), 6),
  'Some nulls expected'
from ANALYTICS.DIM_PROVIDER;

-- Current run readout
select *
from GOVERNANCE.DATA_PROFILE_RESULTS
where run_id = $run_id
order by dataset_name, metric_name, column_name;

-- Semantic model regression tests.
-- Run before publishing semantic model changes; failures should block release.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema INTELLIGENCE;

-- TEST RESULTS TABLE

create or replace table INTELLIGENCE.SEMANTIC_TEST_RESULTS (
    test_id string,
    test_name string,
    test_category string,
    result string,
    actual_value variant,
    expected_condition string,
    run_timestamp timestamp_ntz default current_timestamp()
);

-- DATA EXISTENCE TESTS

-- Test 1: Claims table has data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T01',
    'claims_table_has_data',
    'existence',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from CURATED.DMEPOS_CLAIMS;

-- Test 2: Provider dimension has data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T02',
    'provider_dim_has_data',
    'existence',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from ANALYTICS.DIM_PROVIDER;

-- Test 3: Fact view has data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T03',
    'fact_view_has_data',
    'existence',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from ANALYTICS.FACT_DMEPOS_CLAIMS;

-- DATA QUALITY TESTS

-- Test 4: Total claims should be positive
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T04',
    'claims_sum_positive',
    'quality',
    case when sum(total_supplier_claims) > 0 then 'PASS' else 'FAIL' end,
    to_variant(sum(total_supplier_claims)),
    'sum > 0'
from CURATED.DMEPOS_CLAIMS;

-- Test 5: All states should be valid (2-letter codes or null)
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T05',
    'valid_state_codes',
    'quality',
    case when count(*) = 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'invalid_count = 0'
from ANALYTICS.DIM_PROVIDER
where provider_state is not null and length(provider_state) != 2;

-- Test 6: Payment amounts should be non-negative
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T06',
    'payment_non_negative',
    'quality',
    case when min(avg_supplier_medicare_payment) >= 0 then 'PASS' else 'FAIL' end,
    to_variant(min(avg_supplier_medicare_payment)),
    'min >= 0'
from CURATED.DMEPOS_CLAIMS;

-- Test 7: Allowed amounts should be non-negative
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T07',
    'allowed_non_negative',
    'quality',
    case when min(avg_supplier_medicare_allowed) >= 0 then 'PASS' else 'FAIL' end,
    to_variant(min(avg_supplier_medicare_allowed)),
    'min >= 0'
from CURATED.DMEPOS_CLAIMS;

-- CARDINALITY TESTS

-- Test 8: Reasonable number of unique providers
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T08',
    'provider_cardinality',
    'cardinality',
    case when count(distinct referring_npi) > 1000 then 'PASS' else 'FAIL' end,
    to_variant(count(distinct referring_npi)),
    'distinct_count > 1000'
from ANALYTICS.DIM_PROVIDER;

-- Test 9: Reasonable number of HCPCS codes
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T09',
    'hcpcs_cardinality',
    'cardinality',
    case when count(distinct hcpcs_code) > 100 then 'PASS' else 'FAIL' end,
    to_variant(count(distinct hcpcs_code)),
    'distinct_count > 100'
from CURATED.DMEPOS_CLAIMS;

-- Test 10: Multiple states represented
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T10',
    'state_coverage',
    'cardinality',
    case when count(distinct provider_state) >= 40 then 'PASS' else 'FAIL' end,
    to_variant(count(distinct provider_state)),
    'distinct_count >= 40'
from ANALYTICS.DIM_PROVIDER;

-- RELATIONSHIP TESTS

-- Test 11: Provider join success rate
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T11',
    'provider_join_rate',
    'relationship',
    case when matched_pct > 95.0 then 'PASS' else 'FAIL' end,
    to_variant(round(matched_pct, 2)),
    'match_rate > 95%'
from (
    select
        sum(case when dp.referring_npi is not null then 1 else 0 end)::float / count(*) * 100 as matched_pct
    from CURATED.DMEPOS_CLAIMS dc
    left join ANALYTICS.DIM_PROVIDER dp on dc.referring_npi = dp.referring_npi
);

-- METRIC CALCULATION TESTS

-- Test 12: Payment to allowed ratio in expected range
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T12',
    'payment_allowed_ratio_range',
    'metric',
    case when ratio between 0.5 and 1.1 then 'PASS' else 'FAIL' end,
    to_variant(round(ratio, 4)),
    'ratio between 0.5 and 1.1'
from (
    select avg(avg_supplier_medicare_payment) / nullif(avg(avg_supplier_medicare_allowed), 0) as ratio
    from CURATED.DMEPOS_CLAIMS
);

-- Test 13: Services per claim >= 1
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T13',
    'services_per_claim_valid',
    'metric',
    case when ratio >= 1.0 then 'PASS' else 'FAIL' end,
    to_variant(round(ratio, 2)),
    'ratio >= 1.0'
from (
    select sum(total_supplier_services)::float / nullif(sum(total_supplier_claims), 0) as ratio
    from CURATED.DMEPOS_CLAIMS
);

-- FILTER TESTS

-- Test 14: California filter returns data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T14',
    'california_filter_works',
    'filter',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from ANALYTICS.FACT_DMEPOS_CLAIMS fc
join ANALYTICS.DIM_PROVIDER dp on fc.referring_npi = dp.referring_npi
where dp.provider_state = 'CA';

-- Test 15: Rentals filter returns data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T15',
    'rentals_filter_works',
    'filter',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from ANALYTICS.FACT_DMEPOS_CLAIMS
where supplier_rental_indicator = 'Y';

-- Test 16: DME filter (E-codes) returns data
insert into INTELLIGENCE.SEMANTIC_TEST_RESULTS (test_id, test_name, test_category, result, actual_value, expected_condition)
select
    'T16',
    'dme_filter_works',
    'filter',
    case when count(*) > 0 then 'PASS' else 'FAIL' end,
    to_variant(count(*)),
    'count > 0'
from ANALYTICS.FACT_DMEPOS_CLAIMS
where hcpcs_code like 'E%';

-- TEST SUMMARY

-- View: Test Results Summary
create or replace view INTELLIGENCE.SEMANTIC_TEST_SUMMARY as
select
    test_category,
    count(*) as total_tests,
    sum(case when result = 'PASS' then 1 else 0 end) as passed,
    sum(case when result = 'FAIL' then 1 else 0 end) as failed,
    round(sum(case when result = 'PASS' then 1 else 0 end)::float / count(*) * 100, 1) as pass_rate_pct
from INTELLIGENCE.SEMANTIC_TEST_RESULTS
where run_timestamp = (select max(run_timestamp) from INTELLIGENCE.SEMANTIC_TEST_RESULTS)
group by test_category;

-- View: Failed Tests Detail
create or replace view INTELLIGENCE.SEMANTIC_TEST_FAILURES as
select
    test_id,
    test_name,
    test_category,
    actual_value,
    expected_condition,
    run_timestamp
from INTELLIGENCE.SEMANTIC_TEST_RESULTS
where result = 'FAIL'
  and run_timestamp = (select max(run_timestamp) from INTELLIGENCE.SEMANTIC_TEST_RESULTS);

-- Final summary output
select
    'SEMANTIC MODEL TEST RESULTS' as report,
    (select count(*) from INTELLIGENCE.SEMANTIC_TEST_RESULTS where run_timestamp = (select max(run_timestamp) from INTELLIGENCE.SEMANTIC_TEST_RESULTS)) as total_tests,
    (select count(*) from INTELLIGENCE.SEMANTIC_TEST_RESULTS where result = 'PASS' and run_timestamp = (select max(run_timestamp) from INTELLIGENCE.SEMANTIC_TEST_RESULTS)) as passed,
    (select count(*) from INTELLIGENCE.SEMANTIC_TEST_RESULTS where result = 'FAIL' and run_timestamp = (select max(run_timestamp) from INTELLIGENCE.SEMANTIC_TEST_RESULTS)) as failed;

-- Show any failures
select * from INTELLIGENCE.SEMANTIC_TEST_FAILURES;

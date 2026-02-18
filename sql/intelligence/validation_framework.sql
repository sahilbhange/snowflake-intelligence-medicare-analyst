-- Human validation framework for comparing AI outputs to analyst-reviewed expectations.
-- Includes seed questions, feedback loop tables, and summary views.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema INTELLIGENCE;

-- BUSINESS QUESTIONS CATALOG
-- Questions that stakeholders ask, with human-verified expected answers.

create or replace table INTELLIGENCE.BUSINESS_QUESTIONS (
    question_id string primary key,
    question_category string,        -- 'operational', 'strategic', 'compliance', 'financial'
    question_text string,
    expected_answer_summary string,  -- Human-written expected answer
    expected_sql string,             -- SQL a human analyst would write
    expected_result_sample string,   -- Sample output
    complexity string,               -- 'simple', 'moderate', 'complex'
    requires_join boolean default false,
    requires_aggregation boolean default true,
    created_by string,
    validated boolean default false,
    validated_by string,
    created_at timestamp_ntz default current_timestamp()
);

-- ANALYST INSIGHTS
-- Insights discovered by human analysts during exploratory analysis.

create or replace table INTELLIGENCE.ANALYST_INSIGHTS (
    insight_id string default uuid_string() primary key,
    insight_category string,         -- 'provider', 'hcpcs', 'geographic', 'payment', 'trend'
    insight_title string,
    insight_description string,
    supporting_query string,         -- SQL that produces the insight
    expected_result string,          -- What the query should return
    business_value string,           -- 'high', 'medium', 'low'
    discovered_by string,
    validated_by string,
    validation_date date,
    created_at timestamp_ntz default current_timestamp()
);

-- AI VALIDATION RESULTS
-- Comparison of AI responses against expected answers.

create or replace table INTELLIGENCE.AI_VALIDATION_RESULTS (
    validation_id string default uuid_string() primary key,
    question_id string,              -- FK to BUSINESS_QUESTIONS
    ai_response_text string,
    ai_generated_sql string,
    ai_result_summary string,
    human_expected_answer string,    -- From BUSINESS_QUESTIONS
    match_score string,              -- 'exact', 'close', 'partial', 'incorrect'
    accuracy_notes string,
    sql_quality string,              -- 'optimal', 'correct', 'suboptimal', 'incorrect'
    sql_quality_notes string,
    validated_by string,
    validation_timestamp timestamp_ntz default current_timestamp()
);

-- SEMANTIC FEEDBACK
-- Feedback loop for improving the semantic model.

create or replace table INTELLIGENCE.SEMANTIC_FEEDBACK (
    feedback_id string default uuid_string() primary key,
    query_log_id string,             -- FK to ANALYST_QUERY_LOG
    question_id string,              -- FK to BUSINESS_QUESTIONS (optional)
    feedback_source string,          -- 'human', 'agent', 'automated'
    feedback_type string,            -- 'accuracy', 'completeness', 'relevance', 'suggestion'
    feedback_text string,
    suggested_improvement string,
    priority string,                 -- 'critical', 'high', 'medium', 'low'
    status string default 'open',    -- 'open', 'reviewed', 'implemented', 'rejected'
    created_at timestamp_ntz default current_timestamp(),
    resolved_at timestamp_ntz
);

-- SEED GOLDEN QUESTIONS (10 questions)

insert into INTELLIGENCE.BUSINESS_QUESTIONS (
    question_id, question_category, question_text, expected_answer_summary,
    expected_sql, complexity, requires_join, requires_aggregation, created_by, validated
) values
-- Simple questions
('GQ01', 'operational', 'What are the top 10 states by total DMEPOS claims?',
 'CA leads with highest claims, followed by TX, FL, NY, PA. California typically has 2x the volume of the second state.',
 'SELECT dp.provider_state, SUM(fc.total_supplier_claims) as claims FROM ANALYTICS.FACT_DMEPOS_CLAIMS fc JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi GROUP BY 1 ORDER BY 2 DESC LIMIT 10',
 'simple', true, true, 'data_analyst', true),

('GQ02', 'operational', 'Which HCPCS codes have the highest claim volume?',
 'E1390 (oxygen concentrator) consistently leads for rentals. A4253 (blood glucose test strips) high for supplies.',
 'SELECT hcpcs_code, hcpcs_description, SUM(total_supplier_claims) as claims FROM ANALYTICS.FACT_DMEPOS_CLAIMS GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 10',
 'simple', false, true, 'data_analyst', true),

('GQ03', 'financial', 'What is the average Medicare payment across all claims?',
 'Overall average Medicare payment is approximately $XX per service (varies by data snapshot).',
 'SELECT ROUND(AVG(avg_supplier_medicare_payment), 2) as avg_payment FROM CURATED.DMEPOS_CLAIMS',
 'simple', false, true, 'data_analyst', true),

('GQ04', 'operational', 'How many unique providers are in the dataset?',
 'Approximately $XXX,XXX unique referring providers (varies by data snapshot).',
 'SELECT COUNT(DISTINCT referring_npi) as provider_count FROM ANALYTICS.DIM_PROVIDER',
 'simple', false, true, 'data_analyst', true),

-- Moderate questions
('GQ05', 'strategic', 'How do rental claims compare to purchase claims by total volume?',
 'Rentals (Y) typically represent XX% of total claims. Non-rentals dominate in supplies categories.',
 'SELECT supplier_rental_indicator, SUM(total_supplier_claims) as claims, SUM(total_supplier_services) as services FROM ANALYTICS.FACT_DMEPOS_CLAIMS GROUP BY 1',
 'moderate', false, true, 'data_analyst', true),

('GQ06', 'geographic', 'Which states have the highest average Medicare payment?',
 'States vary significantly. Some smaller states show higher averages due to specialty mix.',
 'SELECT dp.provider_state, ROUND(AVG(fc.avg_supplier_medicare_payment), 2) as avg_payment FROM ANALYTICS.FACT_DMEPOS_CLAIMS fc JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi WHERE dp.provider_state IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10',
 'moderate', true, true, 'data_analyst', true),

('GQ07', 'provider', 'What are the top provider specialties by claim count?',
 'Internal Medicine, Family Practice, and Nurse Practitioners typically lead in DMEPOS referrals.',
 'SELECT dp.provider_specialty_desc, COUNT(*) as claim_records, SUM(fc.total_supplier_claims) as total_claims FROM ANALYTICS.FACT_DMEPOS_CLAIMS fc JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi GROUP BY 1 ORDER BY 3 DESC LIMIT 10',
 'moderate', true, true, 'data_analyst', true),

-- Complex questions
('GQ08', 'financial', 'What is the payment-to-allowed ratio by state? Which states have the highest ratios?',
 'Most states cluster around 0.8-0.9 ratio. Some outlier states may indicate different payer mix or coding patterns.',
 'SELECT dp.provider_state, ROUND(AVG(fc.avg_supplier_medicare_payment) / NULLIF(AVG(fc.avg_supplier_medicare_allowed), 0), 3) as ratio FROM ANALYTICS.FACT_DMEPOS_CLAIMS fc JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi WHERE dp.provider_state IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 10',
 'complex', true, true, 'data_analyst', true),

('GQ09', 'strategic', 'Show efficiency metrics (claims per provider, beneficiaries per claim) by top specialties.',
 'Efficiency varies significantly. Some specialties see many patients with few claims; others have concentrated billing.',
 'SELECT dp.provider_specialty_desc, COUNT(DISTINCT dp.referring_npi) as providers, SUM(fc.total_supplier_claims) as claims, ROUND(SUM(fc.total_supplier_claims)::float / NULLIF(COUNT(DISTINCT dp.referring_npi), 0), 1) as claims_per_provider FROM ANALYTICS.FACT_DMEPOS_CLAIMS fc JOIN ANALYTICS.DIM_PROVIDER dp ON fc.referring_npi = dp.referring_npi GROUP BY 1 ORDER BY 3 DESC LIMIT 10',
 'complex', true, true, 'data_analyst', true),

('GQ10', 'compliance', 'Which HCPCS codes for DME equipment (E-codes) have the highest payment variance across providers?',
 'High variance codes may indicate pricing inconsistencies or regional differences worth investigating.',
 'SELECT hcpcs_code, hcpcs_description, COUNT(*) as records, ROUND(AVG(avg_supplier_medicare_payment), 2) as avg_pay, ROUND(STDDEV(avg_supplier_medicare_payment), 2) as stddev_pay FROM CURATED.DMEPOS_CLAIMS WHERE hcpcs_code LIKE ''E%'' GROUP BY 1, 2 HAVING COUNT(*) > 100 ORDER BY stddev_pay DESC LIMIT 10',
 'complex', false, true, 'data_analyst', true);

-- SEED ANALYST INSIGHTS

insert into INTELLIGENCE.ANALYST_INSIGHTS (
    insight_category, insight_title, insight_description, supporting_query,
    expected_result, business_value, discovered_by
) values
('provider', 'Provider Concentration',
 'Approximately 15% of referring providers account for 80% of total DMEPOS claims, indicating significant market concentration.',
 'WITH ranked AS (SELECT referring_npi, SUM(total_supplier_claims) as claims, ROW_NUMBER() OVER (ORDER BY SUM(total_supplier_claims) DESC) as rn FROM CURATED.DMEPOS_CLAIMS GROUP BY 1) SELECT ROUND(COUNT(*)::float / (SELECT COUNT(DISTINCT referring_npi) FROM CURATED.DMEPOS_CLAIMS) * 100, 1) as top_pct FROM ranked WHERE claims >= (SELECT SUM(total_supplier_claims) * 0.8 / COUNT(*) FROM CURATED.DMEPOS_CLAIMS)',
 'Pareto distribution confirmed - concentration in top providers',
 'high', 'data_analyst'),

('geographic', 'California Volume Leadership',
 'California consistently leads in DMEPOS claims volume, often 1.5-2x the second highest state (Texas).',
 'SELECT provider_state, SUM(total_supplier_claims) as claims FROM CURATED.DMEPOS_CLAIMS dc JOIN ANALYTICS.DIM_PROVIDER dp ON dc.referring_npi = dp.referring_npi GROUP BY 1 ORDER BY 2 DESC LIMIT 5',
 'CA > TX > FL > NY > PA in typical ranking',
 'high', 'data_analyst'),

('hcpcs', 'Oxygen Equipment Dominance in Rentals',
 'Oxygen-related equipment (E1390, E0431, E0434) dominates rental claims, representing the majority of rental volume.',
 'SELECT hcpcs_code, hcpcs_description, SUM(total_supplier_claims) as claims FROM CURATED.DMEPOS_CLAIMS WHERE supplier_rental_indicator = ''Y'' GROUP BY 1, 2 ORDER BY 3 DESC LIMIT 5',
 'E1390 (oxygen concentrator) is consistently the top rental code',
 'medium', 'data_analyst'),

('payment', 'Payment Variation by Geography',
 'Average Medicare payment for the same HCPCS code can vary 20-30% between highest and lowest paying states.',
 'SELECT hcpcs_code, MIN(avg_pay) as min_state_avg, MAX(avg_pay) as max_state_avg, ROUND((MAX(avg_pay) - MIN(avg_pay)) / NULLIF(MIN(avg_pay), 0) * 100, 1) as variance_pct FROM (SELECT hcpcs_code, provider_state, AVG(avg_supplier_medicare_payment) as avg_pay FROM CURATED.DMEPOS_CLAIMS dc JOIN ANALYTICS.DIM_PROVIDER dp ON dc.referring_npi = dp.referring_npi GROUP BY 1, 2) GROUP BY 1 HAVING COUNT(*) > 10 ORDER BY 4 DESC LIMIT 10',
 'Geographic payment variation of 20-30% is common for many codes',
 'high', 'data_analyst');

-- SEED AI VALIDATION RESULTS (sample comparisons)

insert into INTELLIGENCE.AI_VALIDATION_RESULTS (
    question_id, ai_response_text, ai_generated_sql, ai_result_summary,
    human_expected_answer, match_score, accuracy_notes, sql_quality, sql_quality_notes, validated_by
) values
('GQ01', 'Top states by claims are CA, TX, FL, NY, PA.', 'SELECT provider_state, SUM(total_supplier_claims) AS claims FROM ...',
 'Top 5 states align with expected ranking.', 'CA leads with highest claims, followed by TX, FL, NY, PA.', 'exact',
 'Matches expected ordering and summary.', 'correct', 'Uses proper aggregation and limit.', 'data_analyst'),

('GQ02', 'HCPCS E1390 and A4253 lead in claim volume.', 'SELECT hcpcs_code, SUM(total_supplier_claims) AS claims FROM ...',
 'Top codes include E1390 and A4253.', 'E1390 leads for rentals; A4253 high for supplies.', 'close',
 'Includes expected top codes; minor ordering differences.', 'correct', 'Query structure correct.', 'data_analyst'),

('GQ03', 'Average Medicare payment is about $XX per service.', 'SELECT AVG(avg_supplier_medicare_payment) FROM ...',
 'Average payment computed; needs exact number for final answer.', 'Overall average Medicare payment is approximately $XX per service.', 'partial',
 'Answer lacks numeric value due to placeholder response.', 'correct', 'Query is correct but output not captured.', 'data_analyst'),

('GQ06', 'Highest average payments appear in smaller states.', 'SELECT provider_state, AVG(avg_supplier_medicare_payment) FROM ...',
 'Top states listed; missing null filter.', 'States vary; some smaller states show higher averages.', 'close',
 'Directionally correct; add null filters.', 'suboptimal', 'Should filter null states.', 'data_analyst'),

('GQ08', 'Payment-to-allowed ratios cluster near 0.85.', 'SELECT provider_state, AVG(payment)/AVG(allowed) FROM ...',
 'Ratios computed; no rounding.', 'Most states cluster around 0.8-0.9 ratio.', 'close',
 'Matches expected range; add rounding.', 'correct', 'Aggregation and ratio are correct.', 'data_analyst'),

('GQ10', 'E-codes show high variance across providers.', 'SELECT hcpcs_code, STDDEV(avg_supplier_medicare_payment) FROM ...',
 'Variance by code computed; missing count filter.', 'High variance codes may indicate pricing inconsistencies.', 'partial',
 'Missing HAVING filter to avoid low-count noise.', 'suboptimal', 'Add HAVING COUNT(*) > 100.', 'data_analyst');

-- SEED SEMANTIC FEEDBACK (sample entries)

insert into INTELLIGENCE.SEMANTIC_FEEDBACK (
    query_log_id, question_id, feedback_source, feedback_type, feedback_text,
    suggested_improvement, priority, status
) values
('LOG-001', 'GQ03', 'human', 'accuracy',
 'AI response did not include the numeric average payment.',
 'Ensure queries return numeric outputs and include them in summaries.', 'high', 'open'),

('LOG-002', 'GQ06', 'human', 'completeness',
 'State ranking should exclude null states and clearly label outliers.',
 'Add guidance to filter null states and show top 10 with rounding.', 'medium', 'open'),

('LOG-003', 'GQ10', 'human', 'relevance',
 'Variance results should exclude low-volume codes.',
 'Add HAVING COUNT(*) > 100 to variance queries.', 'medium', 'open');

-- VALIDATION VIEWS

-- Summary of validation results
create or replace view INTELLIGENCE.AI_VALIDATION_SUMMARY as
select
    bq.question_category,
    bq.complexity,
    count(*) as total_questions,
    sum(case when vr.match_score in ('exact', 'close') then 1 else 0 end) as accurate_responses,
    round(sum(case when vr.match_score in ('exact', 'close') then 1 else 0 end)::float / nullif(count(*), 0) * 100, 1) as accuracy_pct,
    sum(case when vr.sql_quality in ('optimal', 'correct') then 1 else 0 end) as correct_sql,
    round(sum(case when vr.sql_quality in ('optimal', 'correct') then 1 else 0 end)::float / nullif(count(*), 0) * 100, 1) as sql_accuracy_pct
from INTELLIGENCE.BUSINESS_QUESTIONS bq
left join INTELLIGENCE.AI_VALIDATION_RESULTS vr on bq.question_id = vr.question_id
group by 1, 2;

-- Questions needing improvement
create or replace view INTELLIGENCE.AI_IMPROVEMENT_CANDIDATES as
select
    bq.question_id,
    bq.question_text,
    bq.question_category,
    bq.complexity,
    vr.match_score,
    vr.accuracy_notes,
    vr.sql_quality,
    vr.sql_quality_notes
from INTELLIGENCE.BUSINESS_QUESTIONS bq
join INTELLIGENCE.AI_VALIDATION_RESULTS vr on bq.question_id = vr.question_id
where vr.match_score not in ('exact', 'close')
   or vr.sql_quality not in ('optimal', 'correct')
order by bq.question_category, bq.complexity;

-- Feedback pipeline status
create or replace view INTELLIGENCE.FEEDBACK_PIPELINE as
select
    status,
    priority,
    feedback_type,
    count(*) as count
from INTELLIGENCE.SEMANTIC_FEEDBACK
group by 1, 2, 3
order by
    case status when 'open' then 1 when 'reviewed' then 2 else 3 end,
    case priority when 'critical' then 1 when 'high' then 2 when 'medium' then 3 else 4 end;

-- VERIFICATION

select 'BUSINESS_QUESTIONS' as table_name, count(*) as row_cnt from INTELLIGENCE.BUSINESS_QUESTIONS
union all
select 'ANALYST_INSIGHTS', count(*) from INTELLIGENCE.ANALYST_INSIGHTS
union all
select 'AI_VALIDATION_RESULTS', count(*) from INTELLIGENCE.AI_VALIDATION_RESULTS
union all
select 'SEMANTIC_FEEDBACK', count(*) from INTELLIGENCE.SEMANTIC_FEEDBACK;

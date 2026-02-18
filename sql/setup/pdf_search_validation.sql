-- Validate PDF search service behavior and basic RAG patterns.
-- Run after `sql/setup/pdf_stage_setup.sql` and `sql/search/cortex_search_pdf.sql`.
-- Reference: docs/reference/embedding_strategy.md
-- Use this as a test runner, not as setup.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- 1) Service existence check.
show cortex search services like 'PDF_SEARCH_SVC' in SEARCH;

select
  name,
  database_name,
  schema_name,
  created_on,
  comment
from table(information_schema.cortex_search_services())
where name = 'PDF_SEARCH_SVC';

-- 2) Basic retrieval sanity check.
select
  file_name,
  page_number,
  left(pdf_text, 200) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH(
    'DMEPOS rental equipment billing rules',
    limit => 5
  )
);

-- 3) Topic coverage check across key policy themes.
select
  'rental_rules' as test_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(SEARCH.PDF_SEARCH_SVC!SEARCH('rental equipment rules', limit => 3))

union all

select
  'fee_schedule',
  file_name,
  page_number,
  left(pdf_text, 150)
from table(SEARCH.PDF_SEARCH_SVC!SEARCH('Medicare fee schedule calculation', limit => 3))

union all

select
  'documentation_requirements',
  file_name,
  page_number,
  left(pdf_text, 150)
from table(SEARCH.PDF_SEARCH_SVC!SEARCH('required documentation DMEPOS', limit => 3));

-- 4) RAG pattern: retrieve policy chunks then answer with Cortex Complete.
with policy_context as (
  select listagg(pdf_text, '\n\n---\n\n') as context_text
  from table(
    SEARCH.PDF_SEARCH_SVC!SEARCH(
      'rental equipment documentation requirements',
      limit => 3
    )
  )
)
select
  snowflake.cortex.complete(
    'mistral-large2',
    array_construct(
      object_construct(
        'role', 'system',
        'content', 'You are a CMS policy assistant. Answer only from provided context.'
      ),
      object_construct(
        'role', 'user',
        'content', concat(
          'Policy Context:\n', context_text,
          '\n\nQuestion: What documentation is required for DMEPOS rental billing?'
        )
      )
    )
  ) as answer
from policy_context;

-- 5) Hybrid check: combine policy context with structured claims metrics.
with policy_context as (
  select listagg(pdf_text, '\n\n') as policy_text
  from table(SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS rental rules', limit => 3))
),
rental_metrics as (
  select
    count(distinct referring_npi) as providers,
    sum(total_supplier_claims) as total_claims,
    avg(avg_supplier_medicare_payment) as avg_payment
  from ANALYTICS.FACT_DMEPOS_CLAIMS
  where supplier_rental_indicator = 'Y'
)
select
  snowflake.cortex.complete(
    'mistral-large2',
    array_construct(
      object_construct('role', 'system', 'content', 'You are a Medicare policy assistant.'),
      object_construct('role', 'user', 'content', concat(
        'CMS Policy:\n', p.policy_text, '\n\n',
        'Current Metrics:\n',
        '- Providers: ', m.providers, '\n',
        '- Claims: ', m.total_claims, '\n',
        '- Avg Payment: $', round(m.avg_payment, 2), '\n\n',
        'Question: Summarize rental rules and current payment pattern.'
      ))
    )
  ) as comprehensive_answer
from policy_context p
cross join rental_metrics m;

-- 6) Refresh after PDF updates.
alter cortex search service SEARCH.PDF_SEARCH_SVC refresh;

-- Optional cleanup:
-- drop cortex search service if exists SEARCH.PDF_SEARCH_SVC;
-- drop stage if exists SEARCH.PDF_STAGE;

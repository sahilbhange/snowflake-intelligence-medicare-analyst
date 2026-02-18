-- Create PDF search corpus and service for CMS policy docs.
-- Prereq:
-- 1) PDFs uploaded to @SEARCH.PDF_STAGE (see `sql/setup/pdf_stage_setup.sql`)
-- 2) Stage contains files (`list @SEARCH.PDF_STAGE`)
-- Reference: docs/reference/embedding_strategy.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- Confirm staged PDFs are present.
list @SEARCH.PDF_STAGE;

-- Refresh directory metadata so DIRECTORY() sees newly uploaded files.
alter stage SEARCH.PDF_STAGE refresh;

-- Parse staged PDFs into raw text.
create or replace table SEARCH.PDF_RAW_TEXT as
select
  relative_path as file_name,
  to_varchar(
    snowflake.cortex.parse_document(
      @SEARCH.PDF_STAGE,
      relative_path,
      {'mode': 'LAYOUT'}  -- Keep layout cues for better chunk quality.
    ):content
  ) as extracted_layout,
  last_modified
from directory(@SEARCH.PDF_STAGE)
where relative_path ilike '%.pdf';

-- select * from SEARCH.PDF_RAW_TEXT limit 100;

-- Split raw text into searchable chunks.
create or replace table SEARCH.PDF_CHUNKS as
select
  r.file_name,
  c.index as page_number,
  (
    r.file_name || ':\n'
    || coalesce('Header 1: ' || c.value:headers:header_1::string || '\n', '')
    || coalesce('Header 2: ' || c.value:headers:header_2::string || '\n', '')
    || c.value:chunk::string
  ) as pdf_text,
  r.last_modified
from SEARCH.PDF_RAW_TEXT r,
  lateral flatten(
    input => snowflake.cortex.split_text_markdown_header(
      r.extracted_layout,
      object_construct('#', 'header_1', '##', 'header_2'),
      2000, -- Chunk size
      300   -- Overlap to preserve context between chunks
    )
  ) c
where r.extracted_layout is not null
  and c.value:chunk is not null
  and length(c.value:chunk::string) > 0;

-- Create search service over parsed PDF chunks.
create or replace cortex search service SEARCH.PDF_SEARCH_SVC
  on pdf_text
  attributes file_name, page_number, last_modified
  warehouse = MEDICARE_POS_WH
  target_lag = '1 day'
  comment = 'CMS policy manual search with automatic PDF parsing and hybrid search'
as (
  select
    pdf_text,
    file_name,
    page_number,
    last_modified
  from SEARCH.PDF_CHUNKS
);

-- Grant access for agent/runtime role.
grant usage on cortex search service MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC
  to role MEDICARE_POS_INTELLIGENCE;

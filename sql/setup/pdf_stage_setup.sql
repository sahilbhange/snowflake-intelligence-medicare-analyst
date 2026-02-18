-- Prepare SEARCH.PDF_STAGE for CMS policy PDFs used by PDF search.
-- Run after `sql/setup/setup_user_and_roles.sql`.
-- Reference: docs/reference/embedding_strategy.md

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- Stage keeps uploaded PDF files + directory metadata for listing.
create stage if not exists SEARCH.PDF_STAGE
  directory = (enable = true)
  encryption = (type = 'SNOWFLAKE_SSE')
  comment = 'CMS policy PDFs for Cortex Search';

show stages like 'PDF_STAGE' in SEARCH;

-- Upload from local machine (Snow CLI):
-- make pdf-upload
--
-- Manual equivalent (snow sql does not support -d/-s flags):
-- snow sql -c sf_int -q "USE ROLE MEDICARE_POS_INTELLIGENCE; USE DATABASE MEDICARE_POS_DB; USE SCHEMA SEARCH; PUT 'file://<absolute-repo-path>/pdf/cms_manuals/*.pdf' @SEARCH.PDF_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;"

-- Optional Snowsight upload:
-- Data > Databases > MEDICARE_POS_DB > SEARCH > Stages > PDF_STAGE > Upload Files

-- Validate staged files.
list @SEARCH.PDF_STAGE;

-- Sync directory metadata after uploads so DIRECTORY() can see files.
alter stage SEARCH.PDF_STAGE refresh;

-- Quick parser smoke test before building PDF search service.
select
  relative_path,
  snowflake.cortex.parse_document(
    @SEARCH.PDF_STAGE,
    relative_path,
    {'mode': 'LAYOUT'}
  ):content::string as extracted_text
from directory(@SEARCH.PDF_STAGE)
where relative_path ilike '%.pdf'
limit 1;

-- Next:
-- 1) Run `make pdf-upload` (if local PDFs exist)
-- 2) Run `sql/search/cortex_search_pdf.sql`
-- 3) Run `sql/setup/pdf_search_validation.sql`

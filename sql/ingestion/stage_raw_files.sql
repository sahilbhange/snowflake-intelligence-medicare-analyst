-- Upload local CMS/FDA files into RAW internal stages.
-- Prereq: run `make data` so local files exist under data/.
-- This script is safe to rerun; OVERWRITE=TRUE keeps stage contents fresh.
-- If local files are stored elsewhere, update PUT file:// paths in this file.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema RAW;

-- Ensure stages exist before PUT.
create stage if not exists RAW.RAW_DMEPOS_STAGE;
create stage if not exists RAW.RAW_GUDID_STAGE;

-- CMS claims JSON.
put 'file://data/dmepos_referring_provider.json'
  @RAW.RAW_DMEPOS_STAGE
  auto_compress = true
  overwrite = true;

-- FDA GUDID delimited text files (uploaded as .txt.gz with AUTO_COMPRESS).
put 'file://data/gudid_delimited/*.txt'
  @RAW.RAW_GUDID_STAGE
  auto_compress = true
  overwrite = true;

-- Quick visibility check.
list @RAW.RAW_DMEPOS_STAGE;
list @RAW.RAW_GUDID_STAGE;

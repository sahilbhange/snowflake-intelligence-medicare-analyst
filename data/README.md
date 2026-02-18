# Data Setup

Download public datasets into this folder before loading into Snowflake. (Git ignored—files stay local.)

## Context

This demo analyzes **Medicare DMEPOS billing claims** (wheelchairs, oxygen, diabetic supplies, etc.) matched with **FDA device catalogs**. Combine them to understand utilization patterns, costs, and device metadata by provider.

## Quick Start

Run both downloads (~10 min total):

```bash
# 1. CMS DMEPOS claims (~50-200 MB)
python data/dmepos_referring_provider_download.py --max-rows 1000000

# 2. FDA device catalog (~300 MB)
bash data/data_download.sh
```

Files go to: `dmepos_referring_provider.json` and `gudid_delimited/` under `data/`

## Manual Download (No Scripts)

If your environment blocks `curl`/Python network access, you can download both datasets via the browser and drop them into this folder.

### FDA GUDID (Delimited Full Release)

1. Go to: https://accessgudid.nlm.nih.gov/download
2. Find the **LATEST FULL RELEASE** section, then download the **Delimited Files / Delimited Full Release** zip (pipe-delimited `.txt` files).
3. Unzip it into `data/gudid_delimited/` so files like `device.txt`, `productCodes.txt`, etc. land directly in that folder.

Tip: If you downloaded the “full release” zip (not delimited), go back and grab the *delimited* zip—this pipeline expects the delimited `.txt` files.

### CMS DMEPOS Referring Provider

This project pulls the data from the CMS dataset API. If you want to download manually:

1. Open the dataset API endpoint in your browser (JSON):  
   https://data.cms.gov/data-api/v1/dataset/86b4807a-d63a-44be-bfdf-ffd398d5e623/data?format=json&size=5000&offset=0
2. Save the response and (if needed) combine additional pages by increasing `offset` (pagination).
3. Output file should be named `data/dmepos_referring_provider.json`.

Note: For a complete download, the Python script is still the easiest option because it handles pagination for you.

## What You Get

| Dataset | Source | Use Case |
|---------|--------|----------|
| **CMS DMEPOS** | CMS public API | Claims by provider + device code |
| **FDA GUDID** | FDA release | Device metadata, UDI mappings, manufacturers |

## Options

- Reduce demo size: `--max-rows 100000` (CMS only)
- Custom output: `--out data/custom_name.json` (CMS only)
- Specific release: `GUDID_RELEASE=YYYYMMDD bash data/data_download.sh` (FDA only)
- Force latest release: `GUDID_RELEASE=latest bash data/data_download.sh` (FDA only)

## Next Steps

Load to Snowflake: See [`sql/ingestion/load_raw_data.sql`](../sql/ingestion/load_raw_data.sql)

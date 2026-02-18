#!/usr/bin/env python3
"""Download DMEPOS Referring Provider data from CMS into a JSON file."""

import argparse
import json
import os
import sys
from urllib.parse import urlencode
from urllib.request import urlopen


def fetch_page(base_url, params):
    """Fetch one paginated page from the CMS API."""
    url = f"{base_url}?{urlencode(params)}"
    with urlopen(url) as response:
        return json.load(response)


def parse_args():
    """Parse CLI arguments for output path and row limits."""
    parser = argparse.ArgumentParser(description="Download CMS DMEPOS provider data.")
    parser.add_argument(
        "--out",
        default=os.path.join(os.path.dirname(__file__), "dmepos_referring_provider.json"),
        help="Output JSON file path (default: data/dmepos_referring_provider.json)",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=1_000_000,
        help="Maximum rows to download (default: 1000000)",
    )
    return parser.parse_args()


def main():
    """Stream CMS API pages into a single JSON array on disk."""
    args = parse_args()
    os.makedirs(os.path.dirname(args.out), exist_ok=True)

    base_url = "https://data.cms.gov/data-api/v1/dataset/86b4807a-d63a-44be-bfdf-ffd398d5e623/data"
    page_size = 5000
    offset = 0
    total_rows = 0

    with open(args.out, "w", encoding="utf-8") as f:
        f.write("[")
        first = True
        while True:
            params = {"format": "json", "size": page_size, "offset": offset}
            rows = fetch_page(base_url, params)
            if not rows:
                break
            for row in rows:
                if total_rows >= args.max_rows:
                    break
                if not first:
                    f.write(",")
                f.write(json.dumps(row))
                first = False
                total_rows += 1
            if total_rows >= args.max_rows:
                print(f"Reached row cap of {args.max_rows} rows.", file=sys.stderr)
                break
            offset += len(rows)
            print(f"Fetched {total_rows} rows...", file=sys.stderr)
        f.write("]")

    print(f"Done. Wrote {total_rows} rows to {args.out}")


if __name__ == "__main__":
    main()

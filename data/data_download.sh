#!/usr/bin/env bash
set -euo pipefail

# Download FDA GUDID release files for the demo pipeline.
# Defaults to the latest full release (via RSS).
# Override with `GUDID_RELEASE=YYYYMMDD` or `GUDID_RELEASE=latest`.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# Resolve release date (YYYYMMDD)
gudid_release="${GUDID_RELEASE:-latest}"
if [[ "$gudid_release" == "latest" ]]; then
  rss_url="https://accessgudid.nlm.nih.gov/download.rss?files=full"
  gudid_release="$(
    curl -fsSL -A "Mozilla/5.0" "$rss_url" \
      | grep -Eo 'gudid_full_release_[0-9]{8}\.zip' \
      | head -n 1 \
      | grep -Eo '[0-9]{8}'
  )"
  [[ -n "$gudid_release" ]] || fail "Couldn't find latest full release in RSS: $rss_url"
fi
[[ "$gudid_release" =~ ^[0-9]{8}$ ]] || fail "GUDID_RELEASE must be YYYYMMDD or 'latest' (got: '$gudid_release')"

gudid_url="https://accessgudid.nlm.nih.gov/release_files/download/AccessGUDID_Delimited_Full_Release_${gudid_release}.zip"
gudid_zip="${script_dir}/gudid_delimited_full_${gudid_release}.zip"
gudid_extract_dir="${script_dir}/gudid_delimited"

mkdir -p "$script_dir"

echo "Downloading GUDID release ${gudid_release}..."
tmp_zip="$(mktemp "${gudid_zip}.tmp.XXXXXX")"
trap 'rm -f "$tmp_zip"' EXIT

# -f/-L: fail on HTTP errors; follow redirects (S3-backed objects may redirect)
curl -fL -A "Mozilla/5.0" --retry 3 --retry-delay 2 --connect-timeout 20 -o "$tmp_zip" "$gudid_url" \
  || fail "Download failed. Try a different GUDID_RELEASE or use: GUDID_RELEASE=latest"

# Sanity check before overwriting any existing local zip.
unzip -tq "$tmp_zip" >/dev/null \
  || fail "Downloaded file is not a valid zip. Check GUDID_RELEASE (${gudid_release}) and URL (${gudid_url})"

mv -f "$tmp_zip" "$gudid_zip"
trap - EXIT

echo "Extracting GUDID files..."
rm -rf "$gudid_extract_dir"
mkdir -p "$gudid_extract_dir"
unzip -q "$gudid_zip" -d "$gudid_extract_dir"

echo "Done. Files saved in: $script_dir"

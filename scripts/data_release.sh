#!/usr/bin/env bash
# Upload the raw input files in data/MANIFEST.csv to a GitHub release, as a
# DRAFT. A draft is visible only to the repository owner until it is
# published from the Releases page (or with `gh release edit TAG --draft=false`).
#
#   python3 data/make_manifest.py data-2026.09
#   bash scripts/data_release.sh data-2026.09
#
# Never add confidential data (HFCS) to the manifest: it would be published.
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:?usage: data_release.sh TAG}"
REPO="conway1521/sage_macro"
grep -qi "hfcs" data/MANIFEST.csv && { echo "refusing: HFCS in the manifest"; exit 1; }
FILES=$(tail -n +2 data/MANIFEST.csv | python3 -c '
import csv, sys
print("\n".join(r[0] for r in csv.reader(sys.stdin) if r[2] == sys.argv[1]))' "$TAG")
if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" --repo "$REPO" --draft --title "Raw input data $TAG" \
    --notes "Raw input files for the SAGE model, as downloaded from their official sources. Sources, licences and SHA-256 checksums are in data/MANIFEST.csv; restore them with bash data/fetch_data.sh. No confidential data."
fi
# shellcheck disable=SC2086
gh release upload "$TAG" --repo "$REPO" --clobber $FILES
echo "uploaded to draft release $TAG"

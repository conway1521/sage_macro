#!/usr/bin/env bash
# Restore the raw input files listed in data/MANIFEST.csv from the GitHub
# release that holds them, verify each checksum, and unpack where needed.
#
#   bash data/fetch_data.sh            # everything
#   bash data/fetch_data.sh scf        # only paths containing "scf"
#
# Uses the GitHub CLI when it is logged in, plain curl otherwise (public
# release). Files already present with the right checksum are skipped.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="conway1521/sage_macro"
FILTER="${1:-}"
sum256() { shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1 || sha256sum "$1" | cut -d' ' -f1; }

tail -n +2 data/MANIFEST.csv | python3 -c '
import csv, sys
for r in csv.reader(sys.stdin):
    print("\t".join(r[:7]))' | while IFS=$'\t' read -r path asset tag sha bytes unpack _; do
  [[ -n "$FILTER" && "$path" != *"$FILTER"* ]] && continue
  if [[ -f "$path" && "$(sum256 "$path")" == "$sha" ]]; then
    echo "ok       $path"
  else
    mkdir -p "$(dirname "$path")"
    echo "fetching $path ($((bytes / 1000000)) MB)"
    if gh auth status >/dev/null 2>&1; then
      gh release download "$tag" --repo "$REPO" --pattern "$asset" --dir "$(dirname "$path")" --clobber
    else
      curl -fsSL -o "$path" "https://github.com/$REPO/releases/download/$tag/$asset"
    fi
    [[ "$(sum256 "$path")" == "$sha" ]] || { echo "CHECKSUM MISMATCH: $path"; exit 1; }
  fi
  case "$unpack" in
    unzip)   unzip -o -q "$path" -d "$(dirname "$path")" ;;
    unzip:*) unzip -o -q "$path" -d "$(dirname "$path")/${unpack#unzip:}" ;;
  esac
done
echo "done"

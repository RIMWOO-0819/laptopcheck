#!/usr/bin/env bash
# Builds dist/LaptopCheck-<version>.zip containing a single LaptopCheck/ folder.
# Usage: scripts/build.sh [version]   (default: version from check.ps1)
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
if [ -z "$version" ]; then
  version="v$(grep -oP "^\\\$Version = '\K[^']+" src/check.ps1)"
fi

rm -rf dist && mkdir -p dist/LaptopCheck
for f in START.bat check.ps1 LaptopCheck.html README.txt; do
  cp "src/$f" "dist/LaptopCheck/$f"
done

# Windows tools need CRLF line endings, whatever the checkout settings were.
for f in START.bat check.ps1 README.txt; do
  sed -i 's/\r$//; s/$/\r/' "dist/LaptopCheck/$f"
done

(cd dist && zip -qr "LaptopCheck-${version}.zip" LaptopCheck)
echo "built dist/LaptopCheck-${version}.zip"

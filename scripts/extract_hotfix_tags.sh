#!/bin/bash
set -eu

while read -r line; do
  # Extract version number from hotfix/vX.Y.Z
  tag=$(echo "$line" | sed -E 's/^hotfix\/v?//')
  echo "$tag"
done

#!/bin/bash
set -euo pipefail

PAGE=1
PER_PAGE=100
ALL_BRANCHES=""

while : ; do
  RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github+json" \
                   "https://api.github.com/repos/${GITHUB_REPOSITORY}/branches?per_page=$PER_PAGE&page=$PAGE")

  BRANCH_NAMES=$(echo "$RESPONSE" | jq -r '.[].name')

  if [[ -z "$BRANCH_NAMES" ]]; then
    break
  fi

  ALL_BRANCHES+="$BRANCH_NAMES"$'\n'
  ((PAGE++))
done

echo "$ALL_BRANCHES" > branch-handler-artifact.log
echo "Fetched branches count: $(echo "$ALL_BRANCHES" | wc -l)" >> branch-handler-artifact.log

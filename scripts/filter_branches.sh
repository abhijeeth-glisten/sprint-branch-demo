#!/bin/bash
set -eu

PATTERN="${BRANCH_TYPE}/${TAG_OR_SPRINT}"
echo "Input pattern: '$PATTERN'" >> branch-handler-artifact.log
echo "hotfix_exists=false" >> "$GITHUB_OUTPUT"

MATCHING_BRANCHES=$(grep -i -F "$PATTERN" branch-handler-artifact.log || true)
echo "=== Matched Branches ===" >> branch-handler-artifact.log
echo "$MATCHING_BRANCHES" >> branch-handler-artifact.log

if [[ "$BRANCH_TYPE" == "hotfix" ]]; then
  HOTFIX_BRANCHES=$(echo "$MATCHING_BRANCHES" | grep -i -E '^hotfix/' || true)
  if [[ -n "$HOTFIX_BRANCHES" ]]; then
    echo "=== Hotfix Tags ===" >> branch-handler-artifact.log
    echo "$HOTFIX_BRANCHES" | while read -r branch; do
      tag=$(echo "$branch" | sed -E 's/^hotfix\/v?//I')
      echo "$tag" >> branch-handler-artifact.log
    done
    echo "hotfix_exists=true" >> "$GITHUB_OUTPUT"
  fi
fi

#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"

if [[ -z "$BRANCH_TYPE" || -z "$TAG_OR_SPRINT" ]]; then
  echo "❌ Missing required arguments."
  echo "Usage: $0 <branch_type> <tag_or_sprint>"
  exit 1
fi

echo "✅ Filtering branches for: $BRANCH_TYPE / $TAG_OR_SPRINT"

PATTERN="${BRANCH_TYPE}/${TAG_OR_SPRINT}"
echo "Input pattern: '$PATTERN'" >> branch-handler-artifact.log

GITHUB_OUTPUT="${GITHUB_OUTPUT:-/tmp/github_output.txt}"
echo "hotfix_exists=false" >> "$GITHUB_OUTPUT"

if [[ "$BRANCH_TYPE" == "hotfix" ]]; then
  ESCAPED_PATTERN=$(echo "$PATTERN" | sed -E 's/[][\\.^$*+?{}|()]/\\&/g')
  MATCHING_BRANCHES=$(grep -i -E "^${ESCAPED_PATTERN}" branch-handler-artifact.log || true)
  echo "=== Matched Branches ===" >> branch-handler-artifact.log
  echo "$MATCHING_BRANCHES" >> branch-handler-artifact.log

  HOTFIX_BRANCHES=$(grep -i -E '^hotfix/' branch-handler-artifact.log || true)

  echo "🔍 HOTFIX_BRANCHES:"
  echo "$HOTFIX_BRANCHES"

  if [[ -n "$HOTFIX_BRANCHES" ]]; then
    echo "=== Hotfix Tags ===" >> branch-handler-artifact.log

    echo "$HOTFIX_BRANCHES" | bash scripts/extract_hotfix_tags.sh >> branch-handler-artifact.log || {
      echo "❌ extract_hotfix_tags.sh failed"
      exit 1
    }

    echo "hotfix_exists=true" >> "$GITHUB_OUTPUT"
  else
    echo "ℹ️ No matching hotfix branches found."
  fi
else
  MATCHING_BRANCHES=$(grep -i -F "$PATTERN" branch-handler-artifact.log || true)
  echo "=== Matched Branches ===" >> branch-handler-artifact.log
  echo "$MATCHING_BRANCHES" >> branch-handler-artifact.log
fi

echo "✅ Filter script completed."

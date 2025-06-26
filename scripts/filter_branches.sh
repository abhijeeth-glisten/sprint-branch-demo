#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"

echo "Filtering for: action=$ACTION, type=$BRANCH_TYPE, value=$TAG_OR_SPRINT"

if [[ -z "$BRANCH_TYPE" ]]; then
  echo "Branch type is missing."
  exit 1
fi

# Deduplicate and normalize the artifact file
if [[ -f branch-handler-artifact.log ]]; then
  # Remove carriage returns and trailing whitespace
  tr -d '\r' < branch-handler-artifact.log | sed 's/[[:space:]]\+$//' | sort -u > tmp_branch_list.log
  mv tmp_branch_list.log branch-handler-artifact.log
fi

# If no sprint/tag value is provided, return all type-matching branches
if [[ -z "$TAG_OR_SPRINT" ]]; then
  echo "No sprint or version provided. Listing all branches for '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "No branches found for '$BRANCH_TYPE'"
    touch branch-handler-artifact.log
  }
  exit 0
fi

# Determine if the input is already a full branch name
if grep -Fxq "$TAG_OR_SPRINT" branch-handler-artifact.log; then
  PATTERN="$TAG_OR_SPRINT"
else
  PATTERN="${BRANCH_TYPE}-${TAG_OR_SPRINT}"
fi

echo "Using pattern: '$PATTERN'"

if [[ "$ACTION" == "delete" ]]; then
  echo "Strict matching for deletion"
  MATCH=$(grep -Fx "$PATTERN" branch-handler-artifact.log || true)
  if [[ -z "$MATCH" ]]; then
    echo "No exact match found for '$PATTERN'"
    exit 1
  fi
  echo "$MATCH" > branch-handler-artifact.log
else
  echo "Loose matching for review or keep"
  grep -i -F "$PATTERN" branch-handler-artifact.log > branch-handler-artifact.log || {
    echo "No matching branches found for '$PATTERN'"
    touch branch-handler-artifact.log
  }
fi

echo "Filter complete."

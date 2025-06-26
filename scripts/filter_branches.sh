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

# Deduplicate existing file if it exists
if [[ -f branch-handler-artifact.log ]]; then
  sort -u branch-handler-artifact.log -o branch-handler-artifact.log
fi

# No sprint/tag provided? Return all branches of this type
if [[ -z "$TAG_OR_SPRINT" ]]; then
  echo "No sprint or version provided. Listing all '$BRANCH_TYPE' branches."
  grep -i "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "No branches found for '$BRANCH_TYPE'."
    touch branch-handler-artifact.log
  }
  exit 0
fi

# Determine if user passed an exact branch name that already exists
if grep -Fx "$TAG_OR_SPRINT" branch-handler-artifact.log > /dev/null; then
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
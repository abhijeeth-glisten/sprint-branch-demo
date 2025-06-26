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

# Prepare and normalize the artifact file
if [[ -f branch-handler-artifact.log ]]; then
  tr -d '\r' < branch-handler-artifact.log | sed 's/[[:space:]]\+$//' | sort -u > tmp.log
  mv tmp.log branch-handler-artifact.log
fi

# Handle "list all" case
if [[ -z "$TAG_OR_SPRINT" ]]; then
  echo "No sprint or version provided. Listing all branches with prefix '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "No branches found for '$BRANCH_TYPE'"
    touch branch-handler-artifact.log
  }
  exit 0
fi

# Try all plausible naming formats in order
MATCHED=""
for PATTERN in \
  "$TAG_OR_SPRINT" \
  "${BRANCH_TYPE}/${TAG_OR_SPRINT}" \
  "${BRANCH_TYPE}-${TAG_OR_SPRINT}"; do
  if grep -Fxq "$PATTERN" branch-handler-artifact.log; then
    MATCHED="$PATTERN"
    break
  fi
done

if [[ -z "$MATCHED" ]]; then
  echo "No matching branch found for any variant of '$TAG_OR_SPRINT'"
  exit 1
fi

echo "Using pattern: '$MATCHED'"

if [[ "$ACTION" == "delete" ]]; then
  echo "Strict matching for deletion"
  echo "$MATCHED" > branch-handler-artifact.log
else
  echo "Loose matching for review or keep"
  grep -i -F "$MATCHED" branch-handler-artifact.log > tmp_match.log || {
    echo "No branches matched pattern '$MATCHED'"
    touch tmp_match.log
  }
  mv tmp_match.log branch-handler-artifact.log
fi

echo "Filter complete."

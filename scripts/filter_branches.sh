#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"  # default to review if not passed

echo " Filtering for: action=$ACTION, type=$BRANCH_TYPE, value=$TAG_OR_SPRINT"

if [[ -z "$BRANCH_TYPE" ]]; then
  echo " Branch type is missing."
  exit 1
fi

# Always start fresh
sort -u branch-handler-artifact.log -o branch-handler-artifact.log

# If sprint/tag is blank
if [[ -z "$TAG_OR_SPRINT" ]]; then
  echo " No tag_or_sprint provided. Listing all '$BRANCH_TYPE/' branches."

  grep -i "^${BRANCH_TYPE}/" branch-handler-artifact.log || {
    echo " No $BRANCH_TYPE branches found."
    touch branch-handler-artifact.log
  }

  exit 0
fi

# Compose pattern
if [[ "$TAG_OR_SPRINT" == */* ]]; then
  PATTERN="$TAG_OR_SPRINT"  # full path (e.g., release/v1.4.0)
else
  PATTERN="${BRANCH_TYPE}/${TAG_OR_SPRINT}"  # normal form
fi

echo " Matching pattern: '$PATTERN'"

if [[ "$ACTION" == "delete" ]]; then
  # For deletion, match only exact branch
  echo " Strict matching for deletion..."
  MATCH=$(grep -Fx "$PATTERN" branch-handler-artifact.log || true)
  if [[ -z "$MATCH" ]]; then
    echo " No exact match found for '$PATTERN'"
    exit 1
  fi
  echo "$MATCH" > branch-handler-artifact.log
else
  # For review/keep, show all similar matches
  echo " Loose matching for review/keep..."
  grep -i -F "$PATTERN" branch-handler-artifact.log > branch-handler-artifact.log || {
    echo " No similar branches found for '$PATTERN'"
    touch branch-handler-artifact.log
  }
fi

echo " Branch filter complete."

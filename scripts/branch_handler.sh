#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"
CONFIRM_DELETE="${4:-no}"

echo "[INFO] Action: $ACTION, Branch type: $BRANCH_TYPE, Input value: $TAG_OR_SPRINT"

# Fetch branches
echo "[INFO] Fetching all branches from GitHub..."
PAGE=1
PER_PAGE=100
ALL_BRANCHES=""

while : ; do
  RESPONSE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                   -H "Accept: application/vnd.github+json" \
                   "https://api.github.com/repos/${GITHUB_REPOSITORY}/branches?per_page=$PER_PAGE&page=$PAGE")

  BRANCH_NAMES=$(echo "$RESPONSE" | jq -r '.[].name')
  [[ -z "$BRANCH_NAMES" ]] && break
  ALL_BRANCHES+="$BRANCH_NAMES"$'\n'
  ((PAGE++))
done

echo "$ALL_BRANCHES" | sort -u | sed 's/[[:space:]]\+$//' > branch-handler-artifact.log
[[ ! -s branch-handler-artifact.log ]] && echo "[WARN] No branches found!" && exit 1

# Handle full list case
if [[ -z "$TAG_OR_SPRINT" ]]; then
  echo "[INFO] No tag or sprint provided. Showing all branches starting with '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "[WARN] No branches found for '$BRANCH_TYPE'"
    > branch-handler-artifact.log
    exit 0
  }
  exit 0
fi

if [[ "$ACTION" == "delete" ]]; then
  # Strict matching for delete
  MATCHED=""
  for CANDIDATE in \
    "$TAG_OR_SPRINT" \
    "${BRANCH_TYPE}/${TAG_OR_SPRINT}" \
    "${BRANCH_TYPE}-${TAG_OR_SPRINT}"; do
    if grep -Fxq "$CANDIDATE" branch-handler-artifact.log; then
      MATCHED="$CANDIDATE"
      break
    fi
  done

  if [[ -z "$MATCHED" ]]; then
    echo "[ERROR] No exact matching branch found for '$TAG_OR_SPRINT'"
    exit 1
  fi

  echo "[INFO] Matched branch: $MATCHED"
  echo "$MATCHED" > branch-handler-artifact.log

  # Confirm deletion
  CONFIRM_CLEAN=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ "$CONFIRM_CLEAN" != "YES" ]]; then
    echo "[WARN] Deletion not confirmed. Type YES to proceed."
    exit 1
  fi

  echo "[INFO] Proceeding to delete: $MATCHED"
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  if git ls-remote --heads origin "$MATCHED" | grep -q "$MATCHED"; then
    if git push origin --delete "$MATCHED" > delete.log 2>&1; then
      echo "[INFO] Branch '$MATCHED' deleted via Git push."
    else
      echo "[WARN] Git push failed. Trying GitHub API..."
      cat delete.log
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${MATCHED}")
      [[ "$RESPONSE" == "204" ]] && echo "[INFO] Deleted '$MATCHED' via API." || {
        echo "[ERROR] GitHub API deletion failed (HTTP $RESPONSE)"
        exit 1
      }
    fi
  else
    echo "[WARN] Branch does not exist remotely: '$MATCHED'"
    exit 1
  fi

else
  # Partial matching for review or keep
  grep -i -F "$TAG_OR_SPRINT" branch-handler-artifact.log > tmp_match.log || {
    echo "[WARN] No branches partially matched '$TAG_OR_SPRINT'"
    touch tmp_match.log
  }
  mv tmp_match.log branch-handler-artifact.log
  echo "[INFO] Matching branches written to artifact:"
  cat branch-handler-artifact.log
fi
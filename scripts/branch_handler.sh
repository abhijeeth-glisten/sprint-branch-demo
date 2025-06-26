#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"
CONFIRM_DELETE="${4:-no}"

echo "[INFO] Action: $ACTION | Branch type: $BRANCH_TYPE | Input: $TAG_OR_SPRINT"

# Fetch all remote branches
echo "[INFO] Fetching remote branches from GitHub..."
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

echo "$ALL_BRANCHES" | sort -u > branch-handler-artifact.log
[[ ! -s branch-handler-artifact.log ]] && echo "[WARN] No branches found!" && exit 1

# Case: Review or Keep
if [[ "$ACTION" == "review" || "$ACTION" == "keep" ]]; then
  grep -i -F "$TAG_OR_SPRINT" branch-handler-artifact.log > tmp.log || {
    echo "[WARN] No branches matched '$TAG_OR_SPRINT'"
    touch tmp.log
  }
  mv tmp.log branch-handler-artifact.log
  echo "[INFO] Matched branches:"
  cat branch-handler-artifact.log
  exit 0
fi

# Case: Delete
if [[ "$ACTION" == "delete" ]]; then
  CONFIRM=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  [[ "$CONFIRM" != "YES" ]] && echo "[WARN] Deletion not confirmed. Aborting." && exit 1

  echo "[INFO] Beginning deletion from artifact..."
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  cp branch-handler-artifact.log branch-handler-deletion.log
  echo "[INFO] Targets written to: branch-handler-deletion.log"

  while IFS= read -r BRANCH; do
    [[ -z "$BRANCH" ]] && continue
    echo "[INFO] Deleting branch: $BRANCH"

    if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
      if git push origin --delete "$BRANCH" > delete.log 2>&1; then
        echo "[SUCCESS] '$BRANCH' deleted via Git push."
      else
        echo "[WARN] Git push failed. Trying GitHub API..."
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")
        [[ "$RESPONSE" == "204" ]] && echo "[SUCCESS] '$BRANCH' deleted via API." || {
          echo "[ERROR] Failed to delete '$BRANCH' (HTTP $RESPONSE)"
        }
      fi
    else
      echo "[WARN] Branch '$BRANCH' not found on remote."
    fi
  done < branch-handler-artifact.log

  exit 0
fi

echo "[ERROR] Unknown action: $ACTION"
exit 1

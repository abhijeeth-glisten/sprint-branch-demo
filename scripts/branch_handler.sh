#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"
CONFIRM_DELETE="${4:-no}"

echo "[INFO] Action: $ACTION, Branch type: $BRANCH_TYPE, Input value: $TAG_OR_SPRINT"

# Fetch remote branches
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

# Case: List branches by type
if [[ -z "$TAG_OR_SPRINT" && "$ACTION" != "delete" ]]; then
  echo "[INFO] No tag or sprint provided. Showing all branches starting with '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "[WARN] No branches found for '$BRANCH_TYPE'"
    > branch-handler-artifact.log
    exit 0
  }
  exit 0
fi

# Case: review or keep using partial match
if [[ "$ACTION" == "review" || "$ACTION" == "keep" ]]; then
  grep -i -F "$TAG_OR_SPRINT" branch-handler-artifact.log > tmp_match.log || {
    echo "[WARN] No branches matched pattern '$TAG_OR_SPRINT'"
    touch tmp_match.log
  }
  mv tmp_match.log branch-handler-artifact.log
  echo "[INFO] Matching branches written to artifact:"
  cat branch-handler-artifact.log
  exit 0
fi

# Case: delete exact branches from artifact
if [[ "$ACTION" == "delete" ]]; then
  CONFIRM_CLEAN=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ "$CONFIRM_CLEAN" != "YES" ]]; then
    echo "[WARN] Deletion not confirmed. Type YES to proceed."
    exit 1
  fi

  echo "[INFO] Deleting branches listed in artifact..."
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  while IFS= read -r BRANCH; do
    [[ -z "$BRANCH" ]] && continue
    echo "[INFO] Attempting to delete: '$BRANCH'"

    if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
      if git push origin --delete "$BRANCH" > delete.log 2>&1; then
        echo "[INFO] Deleted '$BRANCH' via Git push."
      else
        echo "[WARN] Push failed for '$BRANCH'. Attempting GitHub API..."
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")
        [[ "$RESPONSE" == "204" ]] && echo "[INFO] Deleted '$BRANCH' via API." || {
          echo "[ERROR] Failed to delete '$BRANCH' (HTTP $RESPONSE)"
        }
      fi
    else
      echo "[WARN] Branch '$BRANCH' not found on remote. Skipping."
    fi
  done < branch-handler-artifact.log
  exit 0
fi

echo "[ERROR] Unknown action: '$ACTION'"
exit 1

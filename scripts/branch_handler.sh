#!/bin/bash
set -eu

BRANCH_TYPE="${1:-}"
TAG_OR_SPRINT="${2:-}"
ACTION="${3:-review}"
CONFIRM_DELETE="${4:-no}"

echo "[INFO] Action: $ACTION | Type: $BRANCH_TYPE | Input: $TAG_OR_SPRINT"

# ========== FETCH BRANCH LIST ==========
echo "[INFO] Fetching all remote branches from GitHub..."
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

SORTED_BRANCHES=$(echo "$ALL_BRANCHES" | sort -u)
[[ -z "$SORTED_BRANCHES" ]] && echo "[ERROR] No branches found." && exit 1

# ========== ACTION: REVIEW or KEEP ==========
if [[ "$ACTION" == "review" || "$ACTION" == "keep" ]]; then
  echo "[INFO] Filtering branches containing keyword: $TAG_OR_SPRINT"
  echo "$SORTED_BRANCHES" | grep -i -F "$TAG_OR_SPRINT" > branch-handler-artifact.log || {
    echo "[WARN] No branches matched '$TAG_OR_SPRINT'"
    > branch-handler-artifact.log
  }
  echo "[INFO] Matching branches saved to branch-handler-artifact.log:"
  cat branch-handler-artifact.log
  exit 0
fi

# ========== ACTION: DELETE ==========
if [[ "$ACTION" == "delete" ]]; then
  CONFIRM=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ "$CONFIRM" != "YES" ]]; then
    echo "[ABORT] Deletion not confirmed. Provide 'YES' as the fourth argument."
    exit 1
  fi

  echo "[INFO] Looking for branches starting with: $TAG_OR_SPRINT"
  MATCHES=$(echo "$SORTED_BRANCHES" | grep -i "^$TAG_OR_SPRINT" || true)

  if [[ -z "$MATCHES" ]]; then
    echo "[WARN] No branches found starting with '$TAG_OR_SPRINT'"
    exit 0
  fi

  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  echo "[INFO] Branches to be deleted:"
  echo "$MATCHES"

  while IFS= read -r BRANCH; do
    [[ -z "$BRANCH" ]] && continue
    echo "[INFO] Deleting: $BRANCH"

    if git push origin --delete "$BRANCH" > delete.log 2>&1; then
      echo "[SUCCESS] '$BRANCH' deleted via Git."
    else
      echo "[WARN] Git push failed, trying GitHub API for '$BRANCH'..."
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")
      [[ "$RESPONSE" == "204" ]] && echo "[SUCCESS] Deleted '$BRANCH' via API." || {
        echo "[ERROR] Failed to delete '$BRANCH' (HTTP $RESPONSE)"
      }
    fi
  done <<< "$MATCHES"

  exit 0
fi

# ========== UNKNOWN ACTION ==========
echo "[ERROR] Unknown action: '$ACTION'"
exit 1

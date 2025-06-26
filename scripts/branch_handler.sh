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

# Handle: list by type only
if [[ -z "$TAG_OR_SPRINT" && "$ACTION" != "delete" ]]; then
  echo "[INFO] No tag or sprint provided. Showing all branches starting with '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "[WARN] No branches found for '$BRANCH_TYPE'"
    > branch-handler-artifact.log
    exit 0
  }
  exit 0
fi

# Handle: delete everything from artifact using partial matches
if [[ "$ACTION" == "delete" ]]; then
  CONFIRM_CLEAN=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ "$CONFIRM_CLEAN" != "YES" ]]; then
    echo "[WARN] Deletion not confirmed. Type YES to proceed."
    exit 1
  fi

  echo "[INFO] Deleting branches based on patterns from artifact..."
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  while IFS= read -r PATTERN; do
    [[ -z "$PATTERN" ]] && continue
    echo "[INFO] Searching for branches matching: '$PATTERN'"

    MATCHES=$(git ls-remote --heads origin | awk '{print $2}' | sed 's#refs/heads/##' | grep -i -F "$PATTERN" || true)

    if [[ -z "$MATCHES" ]]; then
      echo "[WARN] No remote branches matched '$PATTERN'"
      continue
    fi

    echo "$MATCHES" | while read -r BRANCH; do
      echo "[INFO] Deleting remote branch: '$BRANCH'"
      if git push origin --delete "$BRANCH" > delete.log 2>&1; then
        echo "[INFO] Deleted '$BRANCH' via Git push."
      else
        echo "[WARN] Push failed. Trying GitHub API..."
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")
        [[ "$RESPONSE" == "204" ]] && echo "[INFO] Deleted via API." || {
          echo "[ERROR] Failed to delete '$BRANCH' (HTTP $RESPONSE)"
        }
      fi
    done
  done < branch-handler-artifact.log
  exit 0
fi

# Handle: review or keep (partial match)
grep -i -F "$TAG_OR_SPRINT" branch-handler-artifact.log > tmp_match.log || {
  echo "[WARN] No branches matched pattern '$TAG_OR_SPRINT'"
  touch tmp_match.log
}
mv tmp_match.log branch-handler-artifact.log
echo "[INFO] Matching branches written to artifact:"
cat branch-handler-artifact.log
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

# Case 1: List by type
if [[ -z "$TAG_OR_SPRINT" && "$ACTION" != "batch-delete" ]]; then
  echo "[INFO] No tag or sprint provided. Showing all branches starting with '$BRANCH_TYPE'"
  grep -Ei "^${BRANCH_TYPE}[-/]" branch-handler-artifact.log || {
    echo "[WARN] No branches found for '$BRANCH_TYPE'"
    > branch-handler-artifact.log
    exit 0
  }
  exit 0
fi

# Case 2: Batch delete using artifact
if [[ "$ACTION" == "batch-delete" ]]; then
  CONFIRM_CLEAN=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  if [[ "$CONFIRM_CLEAN" != "YES" ]]; then
    echo "[WARN] Batch deletion not confirmed. Type YES to proceed."
    exit 1
  fi

  echo "[INFO] Starting batch deletion from artifact..."
  while IFS= read -r TARGET_BRANCH; do
    [[ -z "$TARGET_BRANCH" ]] && continue
    echo "[INFO] Deleting: $TARGET_BRANCH"

    if git ls-remote --heads origin "$TARGET_BRANCH" | grep -q "$TARGET_BRANCH"; then
      if git push origin --delete "$TARGET_BRANCH" > delete.log 2>&1; then
        echo "[INFO] Deleted '$TARGET_BRANCH' via Git push."
      else
        echo "[WARN] Push failed. Attempting GitHub API..."
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer ${GITHUB_TOKEN}" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${TARGET_BRANCH}")
        [[ "$RESPONSE" == "204" ]] && echo "[INFO] Deleted via API." || {
          echo "[ERROR] Failed to delete '$TARGET_BRANCH' (HTTP $RESPONSE)"
        }
      fi
    else
      echo "[WARN] Branch '$TARGET_BRANCH' not found remotely."
    fi
  done < branch-handler-artifact.log
  exit 0
fi

# Case 3: Single delete/review/keep
if [[ "$ACTION" == "delete" ]]; then
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

  [[ -z "$MATCHED" ]] && echo "[ERROR] No exact match for '$TAG_OR_SPRINT'" && exit 1
  echo "[INFO] Matched branch: $MATCHED"

  CONFIRM_CLEAN=$(echo "$CONFIRM_DELETE" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
  [[ "$CONFIRM_CLEAN" != "YES" ]] && echo "[WARN] Deletion not confirmed." && exit 1

  echo "$MATCHED" > branch-handler-artifact.log
  git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

  if git ls-remote --heads origin "$MATCHED" | grep -q "$MATCHED"; then
    if git push origin --delete "$MATCHED" > delete.log 2>&1; then
      echo "[INFO] Deleted '$MATCHED' via Git push."
    else
      echo "[WARN] Push failed. Attempting GitHub API..."
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${MATCHED}")
      [[ "$RESPONSE" == "204" ]] && echo "[INFO] Deleted via API." || {
        echo "[ERROR] API deletion failed (HTTP $RESPONSE)"
        exit 1
      }
    fi
  else
    echo "[WARN] Branch '$MATCHED' not found remotely."
    exit 1
  fi

else
  # review or keep with partial match
  grep -i -F "$TAG_OR_SPRINT" branch-handler-artifact.log > tmp_match.log || {
    echo "[WARN] No matches for '$TAG_OR_SPRINT'"
    touch tmp_match.log
  }
  mv tmp_match.log branch-handler-artifact.log
  echo "[INFO] Matched branches written:"
  cat branch-handler-artifact.log
fi

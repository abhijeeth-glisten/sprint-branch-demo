#!/bin/bash
set -eu

echo " Starting delete_branches.sh"

# Detect target branch
if [[ "$TAG_OR_SPRINT" == */* ]]; then
  TARGET_BRANCH="$TAG_OR_SPRINT"
else
  TARGET_BRANCH="${BRANCH_TYPE}/${TAG_OR_SPRINT}"
fi

echo " Looking for exact branch: '$TARGET_BRANCH'"

# Deduplicate and locate exact match
MATCHES=$(sort -u branch-handler-artifact.log | grep -Fx "$TARGET_BRANCH" || true)

if [[ -z "$MATCHES" ]]; then
  echo " No match found for '$TARGET_BRANCH'."
  exit 1
fi

COUNT=$(echo "$MATCHES" | wc -l | tr -d '[:space:]')
if [[ "$COUNT" -gt 1 ]]; then
  echo " Multiple matches found for '$TARGET_BRANCH'. Aborting."
  echo "$MATCHES"
  exit 1
fi

BRANCH="$MATCHES"
echo " Ready to delete: '$BRANCH'"

git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  echo " Branch exists remotely."
  if git push origin --delete "$BRANCH" > delete.log 2>&1; then
    echo "🗑️ Branch '$BRANCH' deleted via Git push."
  else
    echo " Git push failed. Trying GitHub API..."
    cat delete.log
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")
    if [[ "$RESPONSE" == "204" ]]; then
      echo " Deleted '$BRANCH' via API."
    else
      echo " API deletion failed (HTTP $RESPONSE)."
      exit 1
    fi
  fi
else
  echo " Branch not found on remote."
  exit 1
fi

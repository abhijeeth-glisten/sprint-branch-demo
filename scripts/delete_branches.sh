#!/bin/bash
set -eu

echo "🚀 Starting delete_branches.sh"

# Define the expected full branch name
BRANCH_PATTERN="${BRANCH_TYPE}/${TAG_OR_SPRINT}"

echo "🔍 Searching for exact branch: '$BRANCH_PATTERN'"

# Deduplicate and trim artifact log before matching
UNIQUE_BRANCHES=$(sort -u branch-handler-artifact.log | grep -Fx "$BRANCH_PATTERN" || true)

if [[ -z "$UNIQUE_BRANCHES" ]]; then
  echo "❌ No branch matching '$BRANCH_PATTERN' found in artifact. Aborting."
  exit 1
fi

COUNT=$(echo "$UNIQUE_BRANCHES" | wc -l | tr -d '[:space:]')
if [[ "$COUNT" -gt 1 ]]; then
  echo "⚠️ Multiple identical entries found for '$BRANCH_PATTERN':"
  echo "$UNIQUE_BRANCHES"
  echo "❌ Aborting to prevent unintended deletion."
  exit 1
fi

BRANCH="$UNIQUE_BRANCHES"
echo "✅ Proceeding to delete branch: '$BRANCH'"

# Configure remote with authenticated token
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Check if branch exists remotely
if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  echo "🌿 Branch exists. Deleting..."

  if git push origin --delete "$BRANCH" > delete.log 2>&1; then
    echo "🗑️ Branch '$BRANCH' deleted via Git push."
  else
    echo "⚠️ Git push failed. Attempting GitHub API fallback..."
    cat delete.log

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")

    if [[ "$RESPONSE" == "204" ]]; then
      echo "✅ Deleted '$BRANCH' via GitHub API."
    else
      echo "❌ GitHub API deletion failed (HTTP $RESPONSE)."
      exit 1
    fi
  fi
else
  echo "❌ Remote branch '$BRANCH' not found. Nothing to delete."
  exit 1
fi

#!/bin/bash
set -euo pipefail

echo "🚀 Starting delete_branches.sh"

BRANCH_PATTERN="${BRANCH_TYPE}/${TAG_OR_SPRINT}"

echo "🧼 Looking for exact match: '$BRANCH_PATTERN' in branch-handler-artifact.log"

# Extract exact-matching branches
MATCHES=$(grep -Fx "$BRANCH_PATTERN" branch-handler-artifact.log || true)

if [[ -z "$MATCHES" ]]; then
  echo "❌ No branch matching '$BRANCH_PATTERN' found in artifact. Aborting."
  exit 1
fi

COUNT=$(echo "$MATCHES" | wc -l)
if [[ "$COUNT" -gt 1 ]]; then
  echo "⚠️ Multiple branches matched '$BRANCH_PATTERN':"
  echo "$MATCHES"
  echo "❌ Aborting to prevent accidental deletions."
  exit 1
fi

BRANCH="$MATCHES"
echo "✅ Ready to delete: '$BRANCH'"

# Authenticate remote for push
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Check existence
if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  echo "🌿 Branch exists on remote. Deleting..."

  if git push origin --delete "$BRANCH" > delete.log 2>&1; then
    echo "🗑️ Deleted '$BRANCH' via Git push."
  else
    echo "⚠️ Git push failed. Trying GitHub API..."
    cat delete.log

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${BRANCH}")

    if [[ "$RESPONSE" == "204" ]]; then
      echo "✅ Deleted '$BRANCH' via GitHub API fallback."
    else
      echo "❌ API deletion failed. Status: $RESPONSE"
      exit 1
    fi
  fi
else
  echo "❌ Branch '$BRANCH' not found remotely. Skipping deletion."
  exit 1
fi

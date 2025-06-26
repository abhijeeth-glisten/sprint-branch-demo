#!/bin/bash
set -eu

echo "Starting delete_branches.sh"

# Read the filtered branch from artifact
if [[ ! -s branch-handler-artifact.log ]]; then
  echo "Artifact log is missing or empty. Aborting."
  exit 1
fi

TARGET_BRANCH=$(head -n 1 branch-handler-artifact.log)

if [[ -z "$TARGET_BRANCH" ]]; then
  echo "No branch found in artifact log. Aborting."
  exit 1
fi

echo "Matched branch for deletion: '$TARGET_BRANCH'"

# Set remote with token for authentication
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Check if branch exists remotely
if git ls-remote --heads origin "$TARGET_BRANCH" | grep -q "$TARGET_BRANCH"; then
  echo "Remote branch exists. Proceeding to delete..."

  if git push origin --delete "$TARGET_BRANCH" > delete.log 2>&1; then
    echo "Branch '$TARGET_BRANCH' deleted via Git push."
  else
    echo "Git push failed. Attempting GitHub API fallback..."
    cat delete.log

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/${TARGET_BRANCH}")

    if [[ "$RESPONSE" == "204" ]]; then
      echo "Deleted '$TARGET_BRANCH' via GitHub API."
    else
      echo "GitHub API deletion failed (HTTP $RESPONSE). Aborting."
      exit 1
    fi
  fi
else
  echo "Remote branch '$TARGET_BRANCH' does not exist. Nothing to delete."
  exit 1
fi

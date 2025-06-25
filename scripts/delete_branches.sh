#!/bin/bash
set -eu
set -o pipefail

echo " Starting delete_branches.sh"

# Ensure origin is authenticated with token
git remote set-url origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"

# Trim and extract valid branch names
echo " Parsing branches from artifact..."
BRANCHES=$(sed 's/^[[:space:]]*//' branch-handler-artifact.log | grep -iE '^(hotfix|sprint)/' || true)

if [[ -z "$BRANCHES" ]]; then
  echo " No matching branches found to delete."
  exit 0
fi

# Loop through each branch and attempt deletion
echo " Deleting matched branches:"
echo "$BRANCHES" | while read -r branch; do
  branch=$(echo "$branch" | tr -d '[:space:]')
  if [[ -n "$branch" ]]; then
    echo " Attempting to delete branch: '$branch'"

    # Validate branch exists on remote
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
      echo " Branch '$branch' exists on remote. Deleting..."
      if git push origin --delete "$branch" > delete.log 2>&1; then
        echo " Successfully deleted '$branch' via Git push."
      else
        echo " Git push failed. Attempting fallback with GitHub API..."
        cat delete.log

        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
          -H "Authorization: Bearer $GITHUB_TOKEN" \
          -H "Accept: application/vnd.github+json" \
          "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/$branch")

        if [[ "$RESPONSE" == "204" ]]; then
          echo " Deleted '$branch' via GitHub API fallback."
        else
          echo " Failed to delete '$branch'. API responded with status: $RESPONSE"
        fi
      fi
    else
      echo " Branch '$branch' does not exist on remote. Skipping."
    fi
  fi
done

#!/bin/bash
set -eu
git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git

grep -iE '^(hotfix|sprint)/' branch-handler-artifact.log | while read -r branch; do
  branch=$(echo "$branch" | tr -d '[:space:]')  # Trim whitespace
  if [[ -n "$branch" ]]; then
    echo "Deleting branch: '$branch'"
    if git push origin --delete "$branch" > delete.log 2>&1; then
      echo "Deleted branch '$branch' via git push"
    else
      echo "git push deletion failed, trying GitHub API..."
      cat delete.log
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/$branch")

      if [[ "$RESPONSE" == "204" ]]; then
        echo "Deleted branch '$branch' via GitHub API"
      else
        echo "Failed to delete branch '$branch' via GitHub API. HTTP status: $RESPONSE"
        exit 1
      fi
    fi
  fi
done

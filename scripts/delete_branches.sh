#!/bin/bash
set -eu

echo " Starting delete_branches.sh"

git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git

FOUND_BRANCHES=0

grep -iE '^(hotfix|sprint)/' branch-handler-artifact.log || {
  echo " No matching branches found in log."
  exit 0
} | while read -r branch; do
  branch=$(echo "$branch" | tr -d '[:space:]')
  if [[ -n "$branch" ]]; then
    echo " Attempting to delete branch: '$branch'"
    FOUND_BRANCHES=1

    if git push origin --delete "$branch" > delete.log 2>&1; then
      echo " Deleted branch '$branch' via git push"
    else
      echo " git push failed. Trying GitHub API..."
      cat delete.log
      RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/$branch")

      if [[ "$RESPONSE" == "204" ]]; then
        echo " Deleted branch '$branch' via GitHub API"
      else
        echo " Failed to delete branch '$branch'. HTTP status: $RESPONSE"
        exit 1
      fi
    fi
  fi
done

echo "✅ Finished delete_branches.sh"

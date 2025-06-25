#!/bin/bash
set -eu

echo " Starting delete_branches.sh"

git remote set-url origin https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git

grep -iE '^(hotfix|sprint)/' branch-handler-artifact.log || {
  echo " No matching branches found."
  exit 0
} | while read -r branch; do
  branch=$(echo "$branch" | tr -d '[:space:]')
  if [[ -n "$branch" ]]; then
    echo " Deleting branch: $branch"

    if git push origin --delete "$branch" > delete.log 2>&1; then
      echo " Deleted via git push"
    else
      echo " git push failed, fallback to GitHub API"
      cat delete.log
      curl -X DELETE \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/$branch"
    fi
  fi
done

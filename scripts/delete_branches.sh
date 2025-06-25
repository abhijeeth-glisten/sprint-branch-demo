#!/bin/bash
set -eu

while read -r branch; do
  if [[ -n "$branch" ]]; then
    echo "Deleting branch: $branch"
    curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github+json" \
         "https://api.github.com/repos/${GITHUB_REPOSITORY}/git/refs/heads/$branch"
  fi
done < <(grep -iE '^(hotfix|sprint)/' branch-handler-artifact.log || true)

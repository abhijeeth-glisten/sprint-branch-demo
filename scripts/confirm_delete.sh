#!/bin/bash
set -euo pipefail

if [[ "$CONFIRM_DELETE" != "YES" ]]; then
  echo "Deletion not confirmed. Set 'confirm_delete' to YES."
  exit 1
fi

echo "Deletion confirmed."

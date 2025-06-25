#!/bin/bash
set -eu

CONFIRM_DELETE=${CONFIRM_DELETE:-NO}
CONFIRM_DELETE_UPPER=$(echo "$CONFIRM_DELETE" | tr '[:lower:]' '[:upper:]')

if [[ "$CONFIRM_DELETE_UPPER" == "YES" || "$CONFIRM_DELETE_UPPER" == "TRUE" ]]; then
  echo "Deletion confirmed."
else
  echo "Deletion not confirmed. Set 'confirm_delete' to YES."
  exit 1
fi

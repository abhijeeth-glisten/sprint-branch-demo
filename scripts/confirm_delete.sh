#!/bin/bash
set -eu

# Normalize input and trim whitespace
CONFIRM_DELETE_INPUT=${CONFIRM_DELETE_INPUT:-no}
NORMALIZED=$(echo "$CONFIRM_DELETE_INPUT" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

if [[ "$NORMALIZED" == "YES" ]]; then
  echo "Deletion confirmed."
else
  echo "Deletion not confirmed. You must type YES (case-insensitive) to proceed."
  exit 1
fi

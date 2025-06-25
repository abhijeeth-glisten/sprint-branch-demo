#!/bin/bash
set -eu

INPUT=${CONFIRM_DELETE_INPUT:-no}
CONFIRM=$(echo "$INPUT" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')

if [[ "$CONFIRM" == "YES" ]]; then
  echo "✅ Deletion confirmed."
else
  echo "❌ Deletion not confirmed. Type YES to proceed."
  exit 1
fi

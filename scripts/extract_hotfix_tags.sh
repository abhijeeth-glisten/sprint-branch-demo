#!/bin/bash
# Extracts hotfix tags from hotfix branches
# Input: logs/hotfix_branches.log
# Output: logs/hotfix_tags.log

set -e

INPUT_FILE="logs/hotfix_branches.log"
OUTPUT_FILE="logs/hotfix_tags.log"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Input file not found: $INPUT_FILE"
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"
cat "$INPUT_FILE" | sed -E 's/^[Hh][Oo][Tt][Ff][Ii][Xx]\///' > "$OUTPUT_FILE"
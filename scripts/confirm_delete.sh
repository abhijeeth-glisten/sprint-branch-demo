#!/bin/bash
set -eu

case "${CONFIRM_DELETE,,}" in
  yes|true)
    echo "Deletion confirmed."
    ;;
  *)
    echo "Deletion not confirmed. Set 'confirm_delete' to YES or true."
    exit 1
    ;;
esac

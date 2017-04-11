#!/bin/bash
set -e

if [ "$#" != 1 ]; then
    echo "Usage: ./check-log-figures.sh <LOG>"
    echo "Example: ./check-log-figures.sh test-all-figures.log"
fi

log_file="$1"

errors=$(cut -d , -f 2 < "$log_file" | grep -vc 200 )
if [ "$errors" != 0 ]; then
    echo "Errors in loading figures:"
    grep -v 200 "$log_file"
    exit "$errors"
fi

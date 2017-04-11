#!/bin/bash
set -e

xargs -P 4 -I {} ./test-figure.sh {} | tee test-all-figures.log

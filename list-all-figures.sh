#!/bin/bash
set -e

aws s3 ls s3://prod-elife-published/articles/ --recursive | grep -o "[0-9]*/elife-.*\.tif" | grep -v -supp | tee all-figures.log


#!/bin/bash
set -e

xargs -n 1 -P 4 -I {} ./load-figure.sh {}

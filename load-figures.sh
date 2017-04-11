#!/bin/bash
set -e

xargs -P 4 -I {} ./load-figure.sh {}

#!/bin/bash
set -e

if [ "$#" -lt 1 ]; then
    echo "Usage: ./test-figure.sh <PATH/TO/FIGURE.tif>"
    echo "Example: ./test-figure.sh 00003/elife-00003-fig1-v1.tif"
    exit 1
fi

figure="${1}"
host="${2:-ci--iiif.elifesciences.org}"

function load() {
    code=$(curl -v "$1" -o /dev/null 2>stderr.log -w "%{http_code}")
    if [ "$code" -eq "504" ]; then
        # retry once
        code=$(curl -v "$1" -o /dev/null 2>stderr.log -w "%{http_code}")
    fi
    echo "$1,$code"
}

load "https://${host}/lax:${figure}/info.json"
load "https://${host}/lax:${figure}/full/full/0/default.jpg"
load "https://${host}/lax:${figure}/full/full/0/default.webp"

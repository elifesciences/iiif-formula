#!/bin/bash
set -e

if [ "$#" != 1 ]; then
    echo "Usage: ./test-figure.sh <PATH/TO/FIGURE.tif>"
    echo "Example: ./test-figure.sh 00003/elife-00003-fig1-v1.tif"
    exit 1
fi

figure="${1}"

function load() {
    code=$(curl -v "$1" -o /dev/null 2>stderr.log -w "%{http_code}")
    echo $1,$code
}

load "https://ci--iiif.elifesciences.org/lax:${figure}/info.json"
load "https://ci--iiif.elifesciences.org/lax:${figure}/full/full/0/default.jpg"

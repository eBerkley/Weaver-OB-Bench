#!/bin/bash

# Moves benchmark results into benchmark/out/$SCHEME/stats
# If anything was already in that dir, move to benchmark/out_old/$SCHEME/stats.

if [[ -z $SCHEME ]]; then
  echo "\$SCHEME must be set."
  exit 1
fi

# If there's already stuff in the folder that we would push stats to
if [ -d "benchmark/out/$SCHEME" ]; then
  rm -rf benchmark/out_old/$SCHEME
  mv benchmark/out/$SCHEME benchmark/out_old/$SCHEME
fi

mkdir -p benchmark/out/$SCHEME
mv benchmark/stats benchmark/out/$SCHEME/stats
mkdir benchmark/stats

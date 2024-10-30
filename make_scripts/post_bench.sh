#!/bin/bash

if [[ -z $SCHEME ]]; then
  echo "\$SCHEME must be set."
  exit 1
fi

# If there's already stuff in the folder that we would push stats to
if [ -d "benchmark/out/$SCHEME" ]; then
  rm -rf benchmark/out_old/$SCHEME
  mv benchmark/out/$SCHEME benchmark/out_old/$SCHEME
fi

mkdir benchmark/out/$SCHEME
mv benchmark/stats benchmark/out/$SCHEME/stats
mkdir benchmark/stats

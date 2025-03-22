#!/bin/bash

if [[ -z $LOADGEN_REPLICAS ]]; then 
  echo Error: .cfg env variables have not been set.
  echo If running vtune profiling, make sure to run vtune_cfgs.py first.
  echo If running bench_all, make sure SCHEME was set properly. 
  echo SCHEME\'s current value: ${SCHEME:-"(empty)"}.
  echo Otherwise, use ./make.sh as a frontend to make, and set the env variables in DEFAULT.cfg.
  exit 1
else
  echo env vars appear to be properly set.
fi

if [[ $BENCH_TYPE = 'STATIC' ]]; then
  if [[ -z $ALLOC_FILE ]]; then
    echo Error: BENCH_TYPE=STATIC, but ALLOC_FILE is not defined. >&2
    exit 1
  else
    echo Running a static benchmark.
  fi
else
  if [[ -z $ALLOC_FILE ]]; then
    echo Running a non-static scheme.
  else 
    echo Error: BENCH_TYPE != STATIC, but ALLOC_FILE is set to $ALLOC_FILE >&2
    exit 1
  fi
fi



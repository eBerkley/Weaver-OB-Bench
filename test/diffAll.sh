#!/bin/bash

cd $(dirname $0)

DIRS=50
FILES=20

for d in $(seq 0 $DIRS); do

  if [ ! -d "./gRPCOut/$d" ]; then
    # echo gRPCOut/$d not found.
    break
  fi

  for f in $(seq 0 $FILES); do
    
    if [[ ! -f "gRPCOut/$d/$f.html" ]]; then
      # echo gRPCOut/$d/$f.html not found.
      break
    fi

    OUT=$(./diff.sh $d $f)
    
    # if diff produced some data
    if [[ ! -z "$OUT" ]]; then
      echo ERROR: task $d line $f.
      echo to see error, run "./test/diff.sh $d $f"
    fi

  done
done

echo if this is the only output, success!
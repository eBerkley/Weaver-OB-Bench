#!/bin/bash

cd $(dirname $0)

scheme=$1

for n in $(./next_grps.sh $scheme); do
  ./make_cfg.sh $n
done


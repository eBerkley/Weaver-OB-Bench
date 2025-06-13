#!/bin/bash

if [[ -z $TMUX ]]; then
  echo Error: Must run in a tmux environment to prevent timeout. >&2
  exit 1
fi

rm cfgs/* &>/dev/null

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=ALLOC/' .env

for a in $(cat todo.txt); do
  ./utils/make_template.sh $a
  ./utils/make_cfg.sh $a
done

make bench_all &>DELETE.txt

./scripts/export_allocations.sh

echo                                      >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo "PREPARING TO RUN STATIC BENCHMARKS" >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo                                      >>DELETE.txt
sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=CUSTOM/' .env

make bench_all &>>DELETE.txt

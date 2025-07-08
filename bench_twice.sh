#!/bin/bash

if [[ -z $TMUX ]]; then
  echo Error: Must run in a tmux environment to prevent timeout. >&2
  exit 1
fi

rm cfgs/* &>/dev/null

minikube delete

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=ALLOC/' .env

if [[ -n $1 ]]; then
  echo "Warning: Preparing to run benchmarks in simple mode."

  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=simple_checkout/' .env
  for a in $(cat todo.txt); do
    ./utils/make_template.sh $a
    cp -r release/base/colocation/$a release/base/colocation/$a-simple_checkout
    ./utils/make_cfg.sh $a-simple_checkout
    # mv cfgs/$a.cfg cfgs/$a-simple_checkout.cfg
  done

else

  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
  for a in $(cat todo.txt); do
    ./utils/make_template.sh $a
    ./utils/make_cfg.sh $a
  done

fi

make bench_all &>DELETE.txt

./scripts/export_allocations.sh

echo                                      >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo "PREPARING TO RUN STATIC BENCHMARKS" >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo                                      >>DELETE.txt
sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=CUSTOM/' .env

make bench_all &>>DELETE.txt

# Reset checkout functionality back to full.
sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
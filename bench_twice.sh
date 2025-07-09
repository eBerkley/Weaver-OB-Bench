#!/bin/bash

if [[ -z $TMUX ]]; then
  echo Error: Must run in a tmux environment to prevent timeout. >&2
  exit 1
fi

rm cfgs/* &>/dev/null

minikube delete

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=ALLOC/' .env

if [[ $1 = "simple" ]]; then
  echo "Preparing to run benchmarks in simple mode."

  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=simple_checkout/' .env
  for a in $(cat todo.txt); do
    ./utils/make_template.sh $a
    cp -r release/base/colocation/$a release/base/colocation/$a-simple_checkout
    ./utils/make_cfg.sh $a-simple_checkout
  done

elif [[ $1 = "arm" ]]; then

  echo "Preparing to run benchmarks in ARM mode."

  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
  for a in $(cat todo.txt); do
    ./utils/make_template.sh $a
    
    rm -rf release/base/colocation/$a-arm/
    cp -r release/base/colocation/$a/ release/base/colocation/$a-arm/
    sed -i 's/pr=1/pr=2/' release/base/colocation/$a-arm/groups_height.cfg
    ./utils/make_cfg.sh $a-arm
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
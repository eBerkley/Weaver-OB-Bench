#!/bin/bash

if [[ -z $TMUX ]]; then
  echo Error: Must run in a tmux environment to prevent timeout. >&2
  exit 1
fi

arm=0
4ch=0
simple=0

for i in "$@"; do
  case $i in
    arm)
      arm=1
      ;;
    4xch)
      4xch=1
      ;;
    simple)
      simple=1
      ;;
  esac
done

rm cfgs/* &>/dev/null

minikube delete



line=$(lscpu | grep 'Core(s) per socket')
pat="([0-9]+)"

if [[ $line =~ $pat ]]; then
  MAX_CORES=${BASH_REMATCH[1]}
else
  echo "warning: Unable to identify number of cores. Defaulting to 36."
  MAX_CORES=36
fi

sed -i -E "s/MAX_CORES=[0-9\-]+/MAX_CORES=$MAX_CORES" .env

scheme_suffix=""

if [[ $simple = 1 ]]; then
  scheme_suffix+="-simple_checkout"
  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=simple_checkout/' .env
else
  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
fi

if [[ $4xch = 1 ]]; then
  scheme_suffix+="-4xch"
  sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=4/' .env
else
  sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=1/' .env
fi

if [[ $arm = 1 ]]; then
  scheme_suffix+="-arm"
  sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-4' .env
else
  sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-2' .env
fi


for a in $(cat todo.txt); do
  ./utils/make_template.sh $a
  rm -rf release/base/colocation/"$a""$scheme_suffix"/ # Just in case.
  cp -r release/base/colocation/$a/ release/base/colocation/"$a""$scheme_suffix"/
  
  if [[ $arm = 1 ]]; then
    sed -i 's/pr=1/pr=2/' release/base/colocation/"$a""$scheme_suffix"/groups_height.cfg
  fi
  ./utils/make_cfg.sh "$a""$scheme_suffix"
done


echo                                      >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo "PREPARING TO RUN ALLOC BENCHMARKS" | tee -a DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo                                      >>DELETE.txt

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=ALLOC/' .env
make bench_all &>DELETE.txt

echo alloc output:              >>DELETE.txt
./scripts/export_allocations.sh >> DELETE.txt

echo                                      >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo "PREPARING TO RUN STATIC BENCHMARKS" | tee -a DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo                                      >>DELETE.txt

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=CUSTOM/' .env
make bench_all &>>DELETE.txt


# Reset env vars.
sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-2' .env
sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=1/' .env

echo Done.
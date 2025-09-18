#!/bin/bash

if [[ -z $TMUX ]]; then
  echo Error: Must run in a tmux environment to prevent timeout. >&2
  exit 1
fi

arm=0
x4ch=0
simple=0
static=0
freq=4
for i in "$@"; do
  case $i in
    arm)
      arm=1
      ;;
    x4ch)
      x4ch=1
      ;;
    simple)
      simple=1
      ;;
    static)
      static=1
      ;;
    freq3)
      freq=3
      ;;
    freq2)
      freq=2
      ;;
    freq4)
      freq=4
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

sed -i -E "s/MAX_CORES=[0-9\-]+/MAX_CORES=$MAX_CORES/" .env

scheme_suffix="-no_turbo"
# scheme_suffix=""

if [[ $simple = 1 ]]; then
  echo simple checkout enabled
  scheme_suffix+="-simple_checkout"
  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=simple_checkout/' .env
else
  sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
fi

if [[ $freq = 3 ]]; then
  echo Warning: Setting cpu frequency to 3GHz!
  scheme_suffix+="-freq3"
  sudo cpupower frequency-set -f 3GHz

elif [[ $freq = 2 ]]; then
  echo Warning: Setting cpu frequency to **2**GHz!
  scheme_suffix+="-freq2"
  sudo cpupower frequency-set -f 2GHz
fi


if [[ $x4ch = 1 ]]; then
  echo x4ch enabled
  scheme_suffix+="-x4ch"
  sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=4/' locust.env
else
  sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=1/' locust.env
fi

if [[ $arm = 1 ]]; then
  echo ARM enabled
  scheme_suffix+="-arm"
  sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-4/' .env
else
  sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-2/' .env
fi


for a in $(cat new.txt); do
  if [[ $static = 0 ]]; then
    rm -f alloc/"$a""$scheme_suffix".cfg
  fi

  rm benchmark/results/"$a""$scheme_suffix".csv
  rm -rf release/base/colocation/"$a""$scheme_suffix"/ # Just in case.
  ./utils/make_template.sh $a
  
  if [[ -n $scheme_suffix ]]; then
    cp -r release/base/colocation/$a/ release/base/colocation/"$a""$scheme_suffix"/
  fi

  if [[ $arm = 1 ]]; then
    sed -i 's/pr=1/pr=2/' release/base/colocation/"$a""$scheme_suffix"/groups_height.cfg
  fi
  ./utils/make_cfg.sh "$a""$scheme_suffix"
done

if [[ $static = 0 ]]; then
  echo                                      >>DELETE.txt
  echo "----------------------------------" >>DELETE.txt
  echo "PREPARING TO RUN ALLOC BENCHMARKS" | tee -a DELETE.txt
  echo "----------------------------------" >>DELETE.txt
  echo                                      >>DELETE.txt

  sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=ALLOC/' .env
  make bench_all &>DELETE.txt

  echo alloc output:              >>DELETE.txt
  ./scripts/export_allocations.sh >> DELETE.txt

else
  echo skipping static benchmarks. | tee DELETE.txt
fi

echo                                      >>DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo "PREPARING TO RUN STATIC BENCHMARKS" | tee -a DELETE.txt
echo "----------------------------------" >>DELETE.txt
echo                                      >>DELETE.txt

sed -i -E 's/BENCH_TYPE=[A-Z]+/BENCH_TYPE=CUSTOM/' .env
make bench_all &>>DELETE.txt


# Reset env vars.
sed -i -E 's/CHECKOUT_FUNCTIONALITY=[a-z\_]+/CHECKOUT_FUNCTIONALITY=full_checkout/' .env
sed -i -E 's/KUBE_CORES=[0-9\-]+/KUBE_CORES=0-2/' .env
sed -i -E 's/LOCUST_CHECKOUT_MOD=[0-9]+/LOCUST_CHECKOUT_MOD=1/' locust.env

if [[ $freq != 4 ]]; then
  echo Returning cpu frequency to 4GHz.
  sudo cpupower frequency-set -f 4GHz  
fi

echo Done.

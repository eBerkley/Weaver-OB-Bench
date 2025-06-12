#!/bin/bash

cd $(dirname $0)/next_grps

go build .
scheme=""
mode=""

for i in "$@"; do
  case $i in
    full|--full|-f)
      mode=full
      ;;

    all|--all|-a)
      if [[ -z $mode ]]; then mode=all; fi
      ;;

    *)
      scheme=$i
  esac
done

if [[ -z $scheme ]]; then
  echo "usage: $0 scheme_name [--all] [--full]" >&2
  exit 1
fi

if [[ $mode = "full" ]]; then
  ./next_grps --grp $scheme --full
elif [[ $mode = "all" ]]; then
  ./next_grps --grp $scheme --all
else
  ./next_grps --grp $scheme 
fi

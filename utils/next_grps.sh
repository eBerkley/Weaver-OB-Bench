#!/bin/bash

cd $(dirname $0)/next_grps

go build .
scheme=""
mode=""

for i in "$@"; do
  case $i in
    full|--full|-f)
      mode="--full $mode"
      ;;

    all|--all|-a)
      mode="--all $mode"
      ;;

    *)
      scheme=$i
  esac
done

if [[ -z $scheme ]]; then
  echo "usage: $0 scheme_name [--all] [--full]" >&2
  exit 1
fi


./next_grps --grp $scheme $mode


#!/bin/bash

cd $(dirname $0)/next_grps

go build .

if [[ $1 = "all" ]] || [[ $1 = "--all" ]] || [[ $1 = "-a" ]]; then
  ./next_grps --grp $2 --all --prev
elif [[ $2 = "all" ]] || [[ $2 = "--all" ]] || [[ $2 = "-a" ]]; then
  ./next_grps --grp $1 --all --prev
else
  ./next_grps --grp $1 --prev
fi

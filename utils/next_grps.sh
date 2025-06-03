#!/bin/bash

cd $(dirname $0)/next_grps

go build .

./next_grps --grp $1

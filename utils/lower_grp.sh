#!/bin/bash

cd $(dirname $0)/parse_spec
go build .

./parse_spec --lowerSpec=true --scheme=$1
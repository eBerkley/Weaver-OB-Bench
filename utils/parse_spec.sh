#!/bin/bash

cd $(dirname $0)/parse_spec

go run ./parse_spec.go --scheme=$1
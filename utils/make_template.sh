#!/bin/bash

cd $(dirname $0)/parse_spec

go build .

name=$1

scheme_dir=../../release/base/colocation/$name
mkdir -p $scheme_dir

echo > $scheme_dir/groups_height.cfg

./parse_spec --fromYaml=false --scheme=$name > $scheme_dir/spec.yaml

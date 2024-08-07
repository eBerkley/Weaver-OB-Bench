#!/bin/bash

cd $(dirname $0)/..

# capture_group='\([0-9a-z]\+\)'
# others='-.*'
# VERSION=$(uuidgen | sed "s/$capture_group$others/\1/")

# echo VERSION=$VERSION

VERSION=$1

cp release/base/loadgen.yaml release/generated/loadgen.yaml

sed -i "s/VERSION/$VERSION/g" release/generated/loadgen.yaml



cd src/loadgenerator

repo=docker.io/eberkley/loadgen:$VERSION

docker build . -t $repo
docker push $repo


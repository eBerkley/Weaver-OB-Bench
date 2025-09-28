#!/bin/bash

version=${1:-"v0.0.4"}

tag="docker.io/eberkley/metrics-collector:$version"
echo $tag

docker build . --build-arg abbr=cfg/managed/abbreviations.cfg -t $tag -f telemetry/Dockerfile
docker push $tag

#!/bin/bash
set -e

cd $(dirname $0)

go build
ip_addr=$(kubectl get svc | grep jaeger-query | awk '{print $3}')

if [[ -z $ip_addr ]]; then
  echo error: could not get ip address of jaeger-query.
  exit 1
fi

./telCol -addr $ip_addr


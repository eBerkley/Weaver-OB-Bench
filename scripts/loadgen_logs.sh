#!/bin/bash

# Simple 1 line script to get logs from the main loadgenerator pod.

lines=${1:-'20'}
kubectl get po -o=name | head -2 | tail -1 | xargs -I % kubectl logs % --tail=$lines
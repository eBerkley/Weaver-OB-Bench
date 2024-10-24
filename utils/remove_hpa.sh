#!/bin/bash

kubectl get hpa | grep -o "^ob\S*" | xargs kubectl delete hpa 

kubectl get pods | grep -o "^\S*-\S*" | xargs kubectl delete pod


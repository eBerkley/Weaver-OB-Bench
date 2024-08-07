#!/bin/bash

kubectl top pod | tail -n +2 | grep -v 'loadgenerator' | awk '{print $2}'
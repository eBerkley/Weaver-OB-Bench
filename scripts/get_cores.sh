#!/bin/bash
cd $(dirname $0)

./cpu/get_mcores.sh | ./cpu/sum_mcores.py
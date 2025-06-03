#!/bin/bash

cd $(dirname $0)/gen_grps

go build .
./fusr >../../grpFile.txt
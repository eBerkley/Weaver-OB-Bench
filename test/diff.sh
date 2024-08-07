#!/bin/bash


cd $(dirname $0)

task=$1
cmd=$2

diff weaverOut/$task/$cmd.html gRPCOut/$task/$cmd.html
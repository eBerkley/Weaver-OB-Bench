#!/bin/python3

import sys
core_sum = 0
for node in sys.stdin.readlines():
    core_sum += int(node.strip()[:-1])

print(f"{core_sum/1000}")
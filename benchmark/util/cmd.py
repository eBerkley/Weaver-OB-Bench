#!/bin/python3

import argparse
from typing import Tuple
from enum import Enum

class Mode(Enum):
    GRAPH='graph'
    TERM='term'
    CSV='csv'

    def __str__(self):
        return self.value

def get_args() -> Tuple[Mode, str, bool]: 
    parser = argparse.ArgumentParser(
        description='analyze results')

    parser.add_argument("-m", "--mode", metavar="MODE", choices=[str(Mode.GRAPH), str(Mode.CSV), str(Mode.TERM)])
    parser.add_argument("-n", "--name", metavar="NAME", type=str, help="name of scheme / group")
    parser.add_argument('-a', '--alloc', action='store_true', help='if specified, disable check for alloc bench type')
    args = parser.parse_args()

    return args.mode, args.name, args.alloc
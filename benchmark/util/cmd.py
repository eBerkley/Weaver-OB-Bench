#!/bin/python3

import argparse
from typing import Tuple, List
from enum import Enum

class Mode(Enum):
    GRAPH='graph'
    TERM='term'
    CSV='csv'
    COMPARE='cmp'
    COMPARE_MANY='cmp_many'
    RANK='rank'

    def __str__(self):
        return self.value

def get_args() -> Tuple[Mode, str, bool, str, int, str]: 
    "mode, scheme_name, allow_alloc, scheme2_name, user_count, value"
    parser = argparse.ArgumentParser(
        description='analyze results')

    parser.add_argument("-m", "--mode", metavar="MODE", choices=[str(Mode.GRAPH), str(Mode.CSV), str(Mode.TERM), str(Mode.COMPARE), str(Mode.COMPARE_MANY), str(Mode.GRAPH), str(Mode.RANK)])
    parser.add_argument("-n", "--name", metavar="NAME", type=str, help="name of scheme / group")
    parser.add_argument('-a', '--alloc', action='store_true', help='if specified, disable check for alloc bench type')
    parser.add_argument("-n2", "--name2", default="", metavar="NAME2", type=str, help="Name of the second scheme. to be used with --mode=COMPARE")
    parser.add_argument("-u", "--users", metavar="USERS", type=int, help="For use with --mode=rank. specify the user count to rank at.")
    parser.add_argument("-v", "--value", choices=["p50", "p99", "cpu"], help="For use with --mode=rank.")
    

    args = parser.parse_args()

    return args.mode, args.name, args.alloc, args.name2, args.users, args.value
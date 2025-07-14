#!/bin/python3

import argparse
from typing import Tuple, List
from enum import Enum
from sys import stdin
from . import shorten_scheme

class Mode(Enum):
    GRAPH='graph'
    GRAPH_MANY='graph_many'
    TERM='term'
    CSV='csv'
    COMPARE='cmp'
    COMPARE_MANY='cmp_many'
    RANK='rank'
    AVG='avg'

    def __str__(self):
        return self.value

class GroupMode(Enum):
    ARM="arm"
    BASE="base"
    SIMPLE="simple"
    X4CH="x4ch"
    INPUT="input"

def get_schemes(careful=None) -> List[str]:
    schemes: List[str] = []
    if careful:
        for ss in stdin:
            for s in ss.split():
                if s.strip() != "":
                    schemes.append(s.strip())
    else:
        for ss in stdin:
            for s in ss.split(" "):
                if s.strip() != "":
                    scm = shorten_scheme(s)
                    schemes.append(scm.strip())

    return schemes

def get_args() -> Tuple[Mode, str, bool, str, int, str, int, bool, GroupMode]: 
    "mode, scheme_name, allow_alloc|SLA mode, scheme2_name, user_count, value, breadth, prune, graph_mode"
    parser = argparse.ArgumentParser(
        description='analyze results')

    parser.add_argument("-m", "--mode", default=str(Mode.TERM), metavar="MODE", choices=[
        str(Mode.GRAPH), str(Mode.CSV), str(Mode.TERM), str(Mode.COMPARE), str(Mode.COMPARE_MANY), str(Mode.GRAPH_MANY), str(Mode.RANK), str(Mode.AVG)])
    parser.add_argument("-n", "--name", metavar="NAME", type=str, help="name of scheme / group")
    parser.add_argument('-a', '--alloc', action='store_true', help='if specified, analyze.py: disable check for alloc bench type. walk.py: run algorithm to maximize throughput instead of minimizing latency.')
    parser.add_argument("-n2", "--name2", default="", metavar="NAME2", type=str, help="Name of the second scheme. to be used with --mode=COMPARE")
    parser.add_argument("-u", "--users", metavar="USERS", type=int, help="For use with --mode=rank. specify the user count to rank at.")
    parser.add_argument("-v", "--value", choices=["p50", "p99", "cpu"], help="For use with --mode=rank.")
    parser.add_argument("-g", "--graph", choices=[GroupMode.ARM.value, GroupMode.BASE.value, GroupMode.INPUT.value, GroupMode.SIMPLE.value, GroupMode.X4CH.value], help="for use with mode=graph_many")
    parser.add_argument('-b', "--breadth", default=3, type=int, help="for use with walk.py")
    parser.add_argument('-p', '--prune', action='store_true')

    args = parser.parse_args()

    return args.mode, args.name, args.alloc, args.name2, args.users, args.value, args.breadth, args.prune, args.graph
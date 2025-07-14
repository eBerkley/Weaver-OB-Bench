#!/bin/python3

from typing import NamedTuple, List, Tuple

from statistics import mean

import platform
SAMPLE_WINDOW=10
if platform.processor() == 'aarch64':
    SAMPLE_WINDOW = 30

class DataPoint(NamedTuple):
    # timestamp: int
    users: int
    p50: List[float]
    p99: List[float]
    rps: List[float]
    cpu: List[float]

    @staticmethod
    def get(d: List[float]):
        return round(mean(d[len(d)-SAMPLE_WINDOW:]), 2)

    def get_users(self): return self.users
    def get_p50(self): return self.get(self.p50)
    def get_p99(self): return self.get(self.p99)
    def get_rps(self): return self.get(self.rps)
    def get_cpu(self): return self.get(self.cpu)


def get_hold_idxs(data: List[int]) -> List[Tuple[int, int]]:
    """This function gets a list of [beginning, end) tuples 
    corresponding to points in `data` where user counts are maintained."""
    ret: List[Tuple[int, int]] = []
    prev_users=-1
    holding=False
    hold_i = 0

    for i in range(len(data)):
        u=data[i]
        if prev_users == u:
            if not holding:
                holding = True
                hold_i = i
        
        elif holding:
            if i > hold_i + 5:
                ret.append((hold_i, i))
            hold_i = 0
            holding = False
            
        prev_users = u
    

    return ret


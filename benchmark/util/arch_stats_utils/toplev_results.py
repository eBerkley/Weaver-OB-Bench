#!/bin/python3

import sys
import os
from enum import Enum
from typing import Dict
from .extra_utils import get_filepath, NOT_IMPLEMENTED

class L1Cycle(Enum):
    FRONTEND_BOUND = "Frontend_Bound"
    BACKEND_BOUND = "Backend_Bound"
    BAD_SPECULATION = "Bad_Speculation"
    RETIRING = "Retiring"

    def __hash__(self):
        return self.value.__hash__()

    def __str__(self):
        return self.value.__str__()

    def __repr__(self):
        return self.value.__repr__()
    
    def is_l1_line(self, line: str) -> bool:
        return f" {self.value} " in line

class CycleBreakdown:
    def __init__(self, fname: str):
        self._fname = fname
        self._breakdown: Dict[L1Cycle, float] = {}
        
        if fname == "":
            for stall in L1Cycle:
                self._breakdown[stall] = NOT_IMPLEMENTED
            return

        with open(self._fname, "r") as f:
            for line in f.readlines():
                for stall in L1Cycle:
                    if not stall.is_l1_line(line):
                        continue
                    prev_text = "% Slots "
                    l = line.strip()
                    l = l[l.find(prev_text) + len(prev_text):].strip().split(" ")[0]
                    # print(stall, l)
                    self._breakdown[stall] = float(l)
                    continue
        
        missing = [metric for metric in L1Cycle if metric not in self._breakdown.keys()]
        for m in missing:
            self._breakdown[m] = NOT_IMPLEMENTED
        # if missing:
        #     raise ValueError(
        #         f"missing the following metrics in {self._fname}: {','.join(missing)}")  
        
        # percent_sum = (self._breakdown[L1Cycle.FRONTEND_BOUND] + 
        #                 self._breakdown[L1Cycle.BACKEND_BOUND] + 
        #                 self._breakdown[L1Cycle.BAD_SPECULATION] + 
        #                 self._breakdown[L1Cycle.RETIRING])

        # if percent_sum < 99:
        #     raise ValueError(f"sum of all cycle percents < 99%: {percent_sum}")

    @property
    def FE(self):
        return self._breakdown[L1Cycle.FRONTEND_BOUND]
    
    @property
    def BE(self):
        return self._breakdown[L1Cycle.BACKEND_BOUND]
    
    @property
    def BAD(self):
        return self._breakdown[L1Cycle.BAD_SPECULATION]
    
    @property
    def RET(self):
        return self._breakdown[L1Cycle.RETIRING]

if __name__ == "__main__":
    fname = get_filepath()
    print(os.path.basename(fname))
    cb = CycleBreakdown(fname)
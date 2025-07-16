#!/bin/python3

import sys
import os
from enum import Enum
from typing import Dict


def get_filepath():

    if len(sys.argv) == 1:
        raise ValueError("Error: Mising file name.")

    fname = sys.argv[1]

    if not os.path.exists(fname):
        raise FileNotFoundError(fname)

    if os.path.isdir(fname):
        raise IsADirectoryError(fname)
    
    return fname

class Metric(Enum):
    INSTRUCTIONS = "instructions"
    CYCLES = "cycles"
    L1_ICACHE_LOAD_MISSES = "L1-icache-load-misses"
    BRANCH_INSTRUCTIONS="branch-instructions"
    BRANCH_MISSES = "branch-misses"
    DTLB_LOADS = "dTLB-loads"
    DTLB_LOAD_MISSES = "dTLB-load-misses"

    L1_DCACHE_LOADS = "L1-dcache-loads"
    L1_DCACHE_LOAD_MISSES = "L1-dcache-load-misses"
    LLC_LOADS = "LLC-loads"
    LLC_LOAD_MISSES = "LLC-load-misses"
    ITLB_LOAD_MISSES = "iTLB-load-misses"

    CONTEXT_SWITCHES = "context-switches"

    def __hash__(self):
        return self.value.__hash__()

    def __str__(self):
        return self.value.__str__()

    def __repr__(self):
        return self.value.__repr__()
    
    def is_metric_line(self, line: str) -> bool:
        return f" {self.value} " in line

    @staticmethod
    def max_len():
        return len(Metric.L1_DCACHE_LOAD_MISSES.value)

class MetricStats:
    def __init__(self, fname: str):
        self._fname = fname
        self._metrics: Dict[Metric, int] = {}
        with open(self._fname, "r") as f:
            for line in f.readlines():
                for metric in Metric:
                    if not metric.is_metric_line(line):
                        continue

                    self._metrics[metric] = int(line.strip().split(" ")[0].replace(",",""))
                    continue
        
        missing = [metric.value for metric in Metric if metric not in self._metrics.keys()]
        if missing:
            raise ValueError(
                f"missing the following metrics in {self._fname}: {','.join(missing)}")    
    
    @property
    def ipc(self):
        return self._metrics[Metric.INSTRUCTIONS] / self._metrics[Metric.CYCLES]
    
    def _mpki(self, met: Metric):
        return (1_000 * self._metrics[met]) / self._metrics[Metric.INSTRUCTIONS]

    def _miss_rate(self, loads: Metric, misses: Metric):
        return self._metrics[misses] / self._metrics[loads]

    @property
    def l1i_mpki(self): return self._mpki(Metric.L1_ICACHE_LOAD_MISSES)
    @property
    def l1d_mpki(self): return self._mpki(Metric.L1_DCACHE_LOAD_MISSES)
    @property
    def dtlb_mpki(self): return self._mpki(Metric.DTLB_LOAD_MISSES)
    @property
    def itlb_mpki(self): return self._mpki(Metric.ITLB_LOAD_MISSES)
    @property
    def llc_mpki(self): return self._mpki(Metric.LLC_LOAD_MISSES)
    @property
    def branch_mpki(self): return self._mpki(Metric.BRANCH_MISSES)

    @property
    def l1i_miss_rate(self): 
        return self._miss_rate(Metric.INSTRUCTIONS, Metric.L1_ICACHE_LOAD_MISSES)

    @property
    def l1d_miss_rate(self): 
        return self._miss_rate(Metric.L1_DCACHE_LOADS, Metric.L1_DCACHE_LOAD_MISSES)

    @property
    def itlb_miss_rate(self): 
        return self._miss_rate(Metric.INSTRUCTIONS, Metric.ITLB_LOAD_MISSES)

    @property
    def llc_miss_rate(self): 
        return self._miss_rate(Metric.LLC_LOADS, Metric.LLC_LOAD_MISSES)

    @property
    def branch_miss_rate(self):
        return self._miss_rate(Metric.BRANCH_INSTRUCTIONS, Metric.BRANCH_MISSES)
    
    @property
    def context_switch_pki(self):
        return self._mpki(Metric.CONTEXT_SWITCHES)

    def _format_base_met(self, met: Metric):
        KPAD=Metric.max_len()
        VPAD=13
        return f"{met.value.ljust(KPAD)} = {str(self._metrics[met]).rjust(VPAD)}\n"

    def _format_mpki_met(self, met_key: str, met_val: float):
        KPAD=Metric.max_len()
        VPAD=13
        
        key = met_key.ljust(KPAD)
        value = f"{met_val:{VPAD}.3f}".rjust(VPAD)
        return f"{key} = {value} \n"

    def _format_missrate_met(self, met_key: str, met_val: float):
        KPAD=Metric.max_len()
        VPAD=13
        
        key = met_key.ljust(KPAD)
        value = f"{met_val*100:5.3f}%".rjust(VPAD)
        return f"{key} = {value} \n"

    def __str__(self):
        s = ""
        
        for metric in Metric:
            s += self._format_base_met(metric)
        
        s+="\n"
        
        s += self._format_mpki_met('IPC', self.ipc)
        s += self._format_mpki_met('L1i MPKI', self.l1i_mpki)
        s += self._format_mpki_met('L1d MPKI', self.l1d_mpki)
        s += self._format_mpki_met('iTLB MPKI', self.itlb_mpki)
        s += self._format_mpki_met('dTLB MPKI', self.dtlb_mpki)
        s += self._format_mpki_met('LLC MPKI', self.llc_mpki)
        s += self._format_mpki_met('Branch MPKI', self.branch_mpki)
        s += self._format_mpki_met('Context Switches PKI', self.context_switch_pki)
        s += self._format_missrate_met('L1i Miss Rate', self.l1i_miss_rate)
        s += self._format_missrate_met('L1d Miss Rate', self.l1d_miss_rate)
        s += self._format_missrate_met('iTLB Miss Rate', self.itlb_miss_rate)
        s += self._format_missrate_met('LLC Miss Rate', self.llc_miss_rate)
        s += self._format_missrate_met('Branch Miss Rate', self.branch_miss_rate)
        
        return s

if __name__ == "__main__":
    mets = MetricStats(get_filepath())
    print(mets)


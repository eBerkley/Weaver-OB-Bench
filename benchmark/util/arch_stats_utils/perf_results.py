#!/bin/python3

import os
from enum import Enum
from typing import Dict
if __name__ == "__main__":
    from extra_utils import get_filepath, NOT_IMPLEMENTED
else:
    from .extra_utils import get_filepath, NOT_IMPLEMENTED

class Metric(Enum):
    INSTRUCTIONS = "instructions"
    CYCLES = "cycles"
    L1_ICACHE_LOAD_MISSES = "L1-icache-load-misses"
    BRANCH_INSTRUCTIONS="branch-instructions"
    BRANCH_MISSES = "branch-misses"
    L1_DCACHE_LOADS = "L1-dcache-loads"
    L1_DCACHE_LOAD_MISSES = "L1-dcache-load-misses"

    ITLB_LOAD_MISSES = "iTLB-load-misses"
    DTLB_LOADS = "dTLB-loads"
    DTLB_LOAD_MISSES = "dTLB-load-misses"
    CONTEXT_SWITCHES = "context-switches"

    # Not valid on altra    
    LLC_LOADS = "LLC-loads"
    LLC_LOAD_MISSES = "LLC-load-misses"
    L2_CACHE_ACCESS = "l2_request.all"
    L2I_CACHE_READ = "l2_rqsts.all_code_rd"
    L2_CACHE_MISS = "l2_request.miss"

    # Not valid on em-02/4
    L2_CACHE_ARM = "l2d_cache"
    L2_CACHE_REFILL = "l2d_cache_refill"


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

class DerivedMetric(Enum):
    IPC="IPC"
    L1I_MPKI="L1i_MPKI"
    L1D_MPKI="L1d_MPKI"
    LLC_MPKI="LLC_MPKI"
    LLC_ACCESS_FREQ="LLC_PKI"
    L2_MPKI="L2_MPKI"
    L2_ACCESS_FREQ="L2_PKI"
    ITLB_MPKI="iTLB_MPKI"
    DTLB_MPKI="dTLB_MPKI"

    L1I_MISS_RATE="L1i_Miss_Rate"
    L1D_MISS_RATE="L1d_Miss_Rate"
    L2C_MISS_RATE="L2C_Miss_Rate"
    LLC_MISS_RATE="LLC_Miss_Rate"

    def __hash__(self):
        return self.value.__hash__()

    def __str__(self):
        return self.value.__str__()

    def __repr__(self):
        return self.value.__repr__()

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
        
        missing = [metric for metric in Metric if metric not in self._metrics.keys()]
        for m in missing:
            self._metrics[m] = NOT_IMPLEMENTED
        
        # if missing:
        #     raise ValueError(
        #         f"missing the following metrics in {self._fname}: {','.join(missing)}")    
    
    @property
    def ipc(self):
        return self._metrics[Metric.INSTRUCTIONS] / self._metrics[Metric.CYCLES]
    
    def _mpki(self, met: Metric):
        if self._metrics[met] == NOT_IMPLEMENTED:
            return NOT_IMPLEMENTED
        return (1_000 * self._metrics[met]) / self._metrics[Metric.INSTRUCTIONS]

    def _miss_rate(self, loads: Metric, misses: Metric):
        if self._metrics[loads] == NOT_IMPLEMENTED or self._metrics[misses] == NOT_IMPLEMENTED:
            return NOT_IMPLEMENTED
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
    def l2_mpki(self): 
        if self._metrics[Metric.L2_CACHE_MISS] == NOT_IMPLEMENTED:
            return self._mpki(Metric.L2_CACHE_REFILL)
        return self._mpki(Metric.L2_CACHE_MISS)

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
    def l2_miss_rate(self):
        if self._metrics[Metric.L2_CACHE_ACCESS] == NOT_IMPLEMENTED:
            return self._miss_rate(Metric.L2_CACHE_ARM, Metric.L2_CACHE_REFILL)
        return self._miss_rate(Metric.L2_CACHE_ACCESS, Metric.L2_CACHE_MISS)

    @property
    def branch_miss_rate(self):
        return self._miss_rate(Metric.BRANCH_INSTRUCTIONS, Metric.BRANCH_MISSES)
    
    @property
    def context_switch_pki(self):
        return self._mpki(Metric.CONTEXT_SWITCHES)

    @property
    def l2_pki(self):
        if self._metrics[Metric.L2_CACHE_ACCESS] == NOT_IMPLEMENTED:
            return self._mpki(Metric.L2_CACHE_ARM)
        return self._mpki(Metric.L2_CACHE_ACCESS)
    
    @property
    def llc_pki(self):
        return self._mpki(Metric.LLC_LOADS)

    def _format_base_met(self, met: Metric):
        KPAD=Metric.max_len()
        VPAD=13
        if self._metrics[met] == NOT_IMPLEMENTED:
            return f"{met.value.ljust(KPAD)} = {"<N/A>".rjust(VPAD)}\n"
        return f"{met.value.ljust(KPAD)} = {str(self._metrics[met]).rjust(VPAD)}\n"

    def _format_mpki_met(self, met_key: str, met_val: float):
        KPAD=Metric.max_len()
        VPAD=13
        key = met_key.ljust(KPAD)
        value = f"{met_val:{VPAD}.3f}".rjust(VPAD)
        if met_val == NOT_IMPLEMENTED:
            value = "<N/A>".rjust(VPAD)
        return f"{key} = {value} \n"

    def _format_missrate_met(self, met_key: str, met_val: float):
        KPAD=Metric.max_len()
        VPAD=13
        
        key = met_key.ljust(KPAD)
        value = f"{met_val*100:5.3f}%".rjust(VPAD)
        if met_val == NOT_IMPLEMENTED:
            value = "<N/A>".rjust(VPAD)
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
        s += self._format_mpki_met('L2C MPKI', self.l2_mpki)
        s += self._format_mpki_met('LLC MPKI', self.llc_mpki)
        s += self._format_mpki_met('Branch MPKI', self.branch_mpki)
        s += self._format_mpki_met('Context Switches PKI', self.context_switch_pki)
        s += self._format_mpki_met('L2 Access PKI', self.l2_pki)
        s += self._format_mpki_met('LLC Access PKI', self.llc_pki)
        s += self._format_missrate_met('L1i Miss Rate', self.l1i_miss_rate)
        s += self._format_missrate_met('L1d Miss Rate', self.l1d_miss_rate)
        s += self._format_missrate_met('iTLB Miss Rate', self.itlb_miss_rate)
        s += self._format_missrate_met('LLC Miss Rate', self.llc_miss_rate)
        s += self._format_missrate_met('L2C Miss Rate', self.l2_miss_rate)
        s += self._format_missrate_met('Branch Miss Rate', self.branch_miss_rate)
        
        return s

if __name__ == "__main__":
    file=get_filepath()
    group = os.path.basename(file).split("_")[0]
    print(f"results for {group}:")
    mets = MetricStats(file)

    print(mets)


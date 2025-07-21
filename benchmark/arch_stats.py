#!/bin/bash

from util import arch_stats_utils as arch
import os
import sys

THISDIR = os.path.dirname(__file__)
STATSDIR = os.path.normpath(os.path.join(THISDIR, "..", "scripts", "vtune_results"))


def get_files(groupname: str, arm=False):
    "groupname -> breakdown_fname, metrics_fname"

    candidates = os.listdir(STATSDIR)
    breakdown=""
    metrics=""

    for c in candidates:
        if c.startswith(groupname) and (not c.startswith(f"{groupname}-")) and (("_arm_" in c) == arm):
            if metrics == "" and c.endswith("_stats.txt") :
                metrics = c
            elif breakdown == "" and c.endswith("_toplev.txt") :
                breakdown = c
    
    # print(f"found breakdown={breakdown}, metrics={metrics}", file=sys.stderr)
    if arm:
        return "", os.path.join(STATSDIR, metrics)
    return os.path.join(STATSDIR, breakdown), os.path.join(STATSDIR, metrics)

if __name__ == "__main__":
    g = arch.get_group()
    if g == None:
        head=f"Name,{arch.DerivedMetric.IPC},{arch.L1Cycle.FRONTEND_BOUND},{arch.L1Cycle.BACKEND_BOUND}"
        head+=f",{arch.L1Cycle.BAD_SPECULATION},{arch.L1Cycle.RETIRING},{arch.DerivedMetric.L1I_MPKI}"
        head+=f",{arch.DerivedMetric.L1D_MPKI},{arch.DerivedMetric.L2_MPKI},{arch.DerivedMetric.LLC_MPKI}"
        head+=f",{arch.DerivedMetric.L2_ACCESS_FREQ},{arch.DerivedMetric.LLC_ACCESS_FREQ},{arch.DerivedMetric.ITLB_MPKI}"
        head+=f",{arch.DerivedMetric.DTLB_MPKI},{arch.DerivedMetric.L1I_MISS_RATE},{arch.DerivedMetric.L1D_MISS_RATE}"
        head+=f",{arch.DerivedMetric.L2C_MISS_RATE},{arch.DerivedMetric.LLC_MISS_RATE}"
        print(head)
        exit(0)
    
    if len(sys.argv) == 2:
        breakdown, metrics = get_files(g, arm=False)
    else:
        breakdown, metrics = get_files(g, arm=True)
    
    cb = arch.CycleBreakdown(breakdown)
    mets = arch.MetricStats(metrics)

    line=f"{g},{mets.ipc},{cb.FE},{cb.BE}"
    line+=f",{cb.BAD},{cb.RET},{mets.l1i_mpki}"
    line+=f",{mets.l1d_mpki},{mets.l2_mpki},{mets.llc_mpki}"
    line+=f",{mets.l2_pki},{mets.llc_pki},{mets.itlb_mpki},{mets.dtlb_mpki}"
    line+=f",{mets.l1i_miss_rate},{mets.l1d_miss_rate},{mets.l2_miss_rate},{mets.llc_miss_rate}"
    
    print(line)


    mets.ipc
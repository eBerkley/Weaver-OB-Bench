#!/bin/python3

from .datalist import  DataList,  plot_data, plot_all
from .env import find_best_match
from .cmd import get_schemes

from typing import List, Optional
import os

BASELINE = "M_Ch_R_S_A_Cu_Ca_E_Pa_Cc_Pr"

def graph_input(name: str, resdir: str, basedir: str):
    schemes = get_schemes(True)
    if len(schemes) < 2:
        raise ValueError(f"Need to use schemes multiple times. schemes: {schemes}")
    
    dls: List[DataList] = []
    for s in schemes:
        res = find_best_match(s, resdir, True)
        dl = DataList()
        dl.from_results(res)
        # print(s, cur_scheme)
        dls.append(dl)
    
    dirname=os.path.join(basedir, "imgs", name)
    os.makedirs(dirname, exist_ok=True)

    plot_data(dls, name, dirname)

# Returns actual paths
def get_suffix(resdir: str, suffix: str):
    arms: List[str] = []
    suffix_str=f"-{suffix}"
    schemes = os.listdir(resdir)
    for scheme in schemes:
        # s = scheme.split(".")[0]
        if suffix_str in scheme:
            arms.append(os.path.join(resdir, scheme))
    return arms


def graph_suffix(name: str, resdir: str, basedir: str, suffix: str):
    suffix_str = f"-{suffix}"
    schemes = get_suffix(resdir, suffix)
    micro: Optional[DataList] = None
    dls: List[DataList] = []
    for s in schemes:
        dl = DataList()
        dl.from_results(s)
        cur_scheme = os.path.basename(s).split(".")
        if cur_scheme == BASELINE + suffix_str:
            micro = dl
        else:
            dls.append(dl)
    
    dirname = os.path.join(basedir, "imgs", name)
    os.makedirs(dirname, exist_ok=True)
    if micro:
        plot_all(dls, micro, name, dirname)
    else:
        plot_data(dls, name, dirname)

def graph_arm(name: str, resdir: str, basedir: str):
    graph_suffix(name, resdir, basedir, "arm")
    



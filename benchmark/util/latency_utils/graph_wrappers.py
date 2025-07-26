#!/bin/python3

from .datalist import  DataList,  plot_data, plot_all, plot_types
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
    baseline: Optional[DataList] = None
    for s in schemes:
        res = find_best_match(s, resdir, True)
        dl = DataList()
        dl.from_results(res)
        if dl.name == BASELINE:
            baseline = dl
        else:
        # print(s, cur_scheme)
            dls.append(dl)
    
    dirname=os.path.join(basedir, "imgs", name)
    os.makedirs(dirname, exist_ok=True)

    if baseline != None:
        plot_all(dls, baseline, name, dirname)
    else:
        plot_data(dls, name, dirname)


def get_suffix(resdir: str, suffix: str, verbose: bool):
    '''Returns actual paths. 
    `suffix` should have the hyphen in it already, if applicable.'''
    arms: List[str] = []
    schemes = os.listdir(resdir)
    for scheme in schemes:
        # s = scheme.split(".")[0]
        if scheme[0] not in "MC":
            continue
        if suffix in scheme and suffix.count("-") == scheme.count("-"):
            if verbose:
                print(scheme)
            arms.append(os.path.join(resdir, scheme))
    return arms


def graph_suffix(name: str, resdir: str, basedir: str, suffix: str, verbose=False):
    suffix_str = f"-{suffix}"
    if suffix == "":
        suffix_str = ""
    
    schemes = get_suffix(resdir, suffix_str, verbose)
    
    micro: Optional[DataList] = None
    dls: List[DataList] = []
    for s in schemes:
        dl = DataList()
        dl.from_results(s)
        cur_scheme = os.path.basename(s).split(".")[0]
        if cur_scheme == BASELINE + suffix_str:
            micro = dl
        # elif cur_scheme.startswith("MCh"):
            # dls.append(dl)
            # continue
        # elif cur_scheme.startswith("Ch"):
            # dls.append(dl)
            # continue
        else:
            dls.append(dl)
            continue
    
    dirname = os.path.join(basedir, "imgs", name)
    os.makedirs(dirname, exist_ok=True)
    if micro:
        plot_all(dls, micro, name, dirname)
    else:
        plot_data(dls, name, dirname)

def graph_arm(name: str, resdir: str, basedir: str):
    graph_suffix(name, resdir, basedir, "arm")

def graph_simple(name: str, resdir: str, basedir: str):

    simples = get_suffix(resdir, "simple_checkout", False)
    simpledls: List[DataList] = []
    basedls: List[DataList] = []

    for scheme in simples:
        base = scheme.replace("-simple_checkout", "")
        basedl = DataList()
        simpledl = DataList()

        basedl.from_results(base)
        simpledl.from_results(scheme)

        basedls.append(basedl)
        simpledls.append(simpledl)
    
    dirname = os.path.join(basedir, "imgs", name)
    os.makedirs(dirname, exist_ok=True)
    plot_types(basedls, simpledls, [], name, dirname)


def graph_x4ch(name: str, resdir: str, basedir: str):
    x4chs = get_suffix(resdir, "4xch", False)
    x4chdls: List[DataList] = []
    basedls: List[DataList] = []

    for scheme in x4chs:

        base = scheme.replace("-4xch", "")
        basedl = DataList()
        simpledl = DataList()

        basedl.from_results(base)
        simpledl.from_results(scheme)

        basedls.append(basedl)
        x4chdls.append(simpledl)
    
    dirname = os.path.join(basedir, "imgs", name)    
    os.makedirs(dirname, exist_ok=True)

    plot_types(basedls, [], x4chdls, name, dirname)



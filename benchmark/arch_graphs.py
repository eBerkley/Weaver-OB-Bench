#!/bin/bash

from enum import Enum
from util.arch_stats_utils import get_filepath, Metric, DerivedMetric, L1Cycle
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os
import sys

THISDIR = os.path.dirname(__file__)
IMGDIR = os.path.join(THISDIR, "imgs", "ARCH_STATS")

def make_MR_graph(fname: str, outname: str):
    os.makedirs(IMGDIR, exist_ok=True)
    df = pd.read_csv(fname)
    names = df["Name"].astype(str).values
    L1I = df[DerivedMetric.L1I_MISS_RATE.value].astype(float).values
    L1D = df[DerivedMetric.L1D_MISS_RATE.value].astype(float).values
    L2C = df[DerivedMetric.L2C_MISS_RATE.value].astype(float).values
    LLC = df[DerivedMetric.LLC_MISS_RATE.value].astype(float).values
    LLC_EXISTS = True

    if LLC[0] < -500 :
        LLC_EXISTS = False

    # LLC_EXISTS=False
    
    WIDTH = 0.3
    if LLC_EXISTS:
        WIDTH=0.4


    if LLC_EXISTS:
        x = np.arange(1, len(df)*2+1)
    else:
        x = np.arange(len(df))

    ind = 0
    for i in range(len(names)): 
        if "comp-" in names[i]:
            ind = i
            break
    
    fig, ax = plt.subplots(1,1, figsize=(12,5))
    
    if LLC_EXISTS:
        
        ax.bar(x[:ind*2:2]-WIDTH*3/2, L1I[:ind], width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x[:ind*2:2]-WIDTH/2,   L1D[:ind], width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x[:ind*2:2]+WIDTH/2,   L2C[:ind], width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 
        ax.bar(x[:ind*2:2]+WIDTH*3/2, LLC[:ind], width=WIDTH, label="LLC", color="tab:green", edgecolor="black") 
        
        ax.bar(x[ind*2::2]-WIDTH*3/2, L1I[ind:], width=WIDTH, color="tab:blue", edgecolor="black") 
        ax.bar(x[ind*2::2]-WIDTH/2,   L1D[ind:], width=WIDTH, color="tab:red",edgecolor="black") 
        ax.bar(x[ind*2::2]+WIDTH/2,   L2C[ind:], width=WIDTH, color="tab:purple", edgecolor="black") 
        ax.bar(x[ind*2::2]+WIDTH*3/2, LLC[ind:], width=WIDTH, color="tab:green", edgecolor="black") 
    else:
        ax.bar(x[:ind]-WIDTH, L1I[:ind], width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x[:ind],       L1D[:ind], width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x[:ind]+WIDTH, L2C[:ind], width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 

        ax.bar(x[ind:]-WIDTH, L1I[ind:], width=WIDTH, color="tab:blue", edgecolor="black") 
        ax.bar(x[ind:],       L1D[ind:], width=WIDTH, color="tab:red", edgecolor="black") 
        ax.bar(x[ind:]+WIDTH, L2C[ind:], width=WIDTH, color="tab:purple", edgecolor="black")  
    fig.autofmt_xdate(bottom=0.3, rotation=45)
    
    plt.legend()
    plt.ylabel("Cache Miss Rate")
    if LLC_EXISTS:
        plt.xticks(x[::2], names)
    else:
        plt.xticks(x, names)
    for i in range(ind):
        ax.get_xticklabels()[i].set_color('red')
    plt.title(outname)
    plt.savefig(os.path.join(IMGDIR, outname))

def make_normalized_MPKI_graph(fname: str, outname: str):
    os.makedirs(IMGDIR, exist_ok=True)

    df = pd.read_csv(fname)

    names = df["Name"].astype(str).values
    L1I = df[DerivedMetric.L1I_MPKI.value].astype(float).values
    L1D = df[DerivedMetric.L1D_MPKI.value].astype(float).values
    L2C = df[DerivedMetric.L2_MPKI.value].astype(float).values
    LLC = df[DerivedMetric.LLC_MPKI.value].astype(float).values
    
    LLC_EXISTS = True

    if LLC[0] < -500 :
        LLC_EXISTS = False
    
    WIDTH = 0.3
    if LLC_EXISTS:
        WIDTH=0.4

    comp_ind = 0
    for i in range(len(names)): 
        if "comp-" in names[i]:
            comp_ind = i
            break

    m_ind = 0
    for i in range(comp_ind, len(names)):
        if names[i] == "comp-m":
            m_ind = i
            break
    
    m_L1I = L1I[m_ind]
    m_L1D = L1D[m_ind]
    m_L2C = L2C[m_ind]
    m_LLC = LLC[m_ind]
    
    names = names[:comp_ind]
    L1I = L1I[:comp_ind]
    L1D = L1D[:comp_ind]
    L2C = L2C[:comp_ind]
    LLC = LLC[:comp_ind]

    if LLC_EXISTS:
        x = np.arange(1, len(names)*2+1)
    else:
        x = np.arange(1, len(names)+1)
    fig, ax = plt.subplots(1,1, figsize=(10,5))

    
    if LLC_EXISTS:    
        ax.bar(x[::2]-WIDTH*3/2, L1I/m_L1I, width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x[::2]-WIDTH/2,   L1D/m_L1D, width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x[::2]+WIDTH/2,   L2C/m_L2C, width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 
        ax.bar(x[::2]+WIDTH*3/2, LLC/m_LLC, width=WIDTH, label="LLC", color="tab:green", edgecolor="black") 
        
    else:
        ax.bar(x-WIDTH, L1I/m_L1I, width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x,       L1D/m_L1D, width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x+WIDTH, L2C/m_L2C, width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 

    fig.autofmt_xdate(bottom=0.3, rotation=45)
    
    plt.legend()
    plt.ylabel("Normalized Cache MPKI")
    if LLC_EXISTS:
        plt.xticks(x[::2], names)
    else:
        plt.xticks(x, names)

    plt.ylim(0.75, 1.25)    


    xmin=x[0] - WIDTH*3
    xmax=x[-1]+WIDTH
    if not LLC_EXISTS:
        xmax += WIDTH*2

    ax.axhline(1, 0,1, color="black", linestyle='dashed', zorder=-1)

    plt.xlim(xmin,xmax)


    
    
    plt.title(outname)
    plt.savefig(os.path.join(IMGDIR, outname))

def make_MPKI_graph(fname: str, outname: str):
    os.makedirs(IMGDIR, exist_ok=True)

    df = pd.read_csv(fname)

    names = df["Name"].astype(str).values
    L1I = df[DerivedMetric.L1I_MPKI.value].astype(float).values
    L1D = df[DerivedMetric.L1D_MPKI.value].astype(float).values
    L2C = df[DerivedMetric.L2_MPKI.value].astype(float).values
    LLC = df[DerivedMetric.LLC_MPKI.value].astype(float).values

    
    LLC_EXISTS = True

    if LLC[0] < -500 :
        LLC_EXISTS = False
    # LLC_EXISTS=False

    # fig, axl = plt.subplots(1, 1)
    
    WIDTH = 0.3
    if LLC_EXISTS:
        WIDTH=0.4


    if LLC_EXISTS:
        x = np.arange(1, len(df)*2+1)
    else:
        x = np.arange(len(df))

    ind = 0
    for i in range(len(names)): 
        if "comp-" in names[i]:
            ind = i
            break
    
    fig, ax = plt.subplots(1,1, figsize=(12,5))
    
    if LLC_EXISTS:    
        ax.bar(x[:ind*2:2]-WIDTH*3/2, L1I[:ind], width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x[:ind*2:2]-WIDTH/2,   L1D[:ind], width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x[:ind*2:2]+WIDTH/2,   L2C[:ind], width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 
        ax.bar(x[:ind*2:2]+WIDTH*3/2, LLC[:ind], width=WIDTH, label="LLC", color="tab:green", edgecolor="black") 
        
        ax.bar(x[ind*2::2]-WIDTH*3/2, L1I[ind:], width=WIDTH, color="tab:blue", edgecolor="black") 
        ax.bar(x[ind*2::2]-WIDTH/2,   L1D[ind:], width=WIDTH, color="tab:red",edgecolor="black") 
        ax.bar(x[ind*2::2]+WIDTH/2,   L2C[ind:], width=WIDTH, color="tab:purple", edgecolor="black") 
        ax.bar(x[ind*2::2]+WIDTH*3/2, LLC[ind:], width=WIDTH, color="tab:green", edgecolor="black") 
    else:
        ax.bar(x[:ind]-WIDTH, L1I[:ind], width=WIDTH, label="L1i", color="tab:blue", edgecolor="black") 
        ax.bar(x[:ind],       L1D[:ind], width=WIDTH, label="L1d", color="tab:red", edgecolor="black") 
        ax.bar(x[:ind]+WIDTH, L2C[:ind], width=WIDTH, label="L2", color="tab:purple", edgecolor="black") 

        ax.bar(x[ind:]-WIDTH, L1I[ind:], width=WIDTH, color="tab:blue", edgecolor="black") 
        ax.bar(x[ind:],       L1D[ind:], width=WIDTH, color="tab:red", edgecolor="black") 
        ax.bar(x[ind:]+WIDTH, L2C[ind:], width=WIDTH, color="tab:purple", edgecolor="black")  
    fig.autofmt_xdate(bottom=0.3, rotation=45)
    
    plt.legend()
    plt.ylabel("Cache MPKI")
    if LLC_EXISTS:
        plt.xticks(x[::2], names)
    else:
        plt.xticks(x, names)
    for i in range(ind):
        ax.get_xticklabels()[i].set_color('red')
    
    plt.title(outname)
    plt.savefig(os.path.join(IMGDIR, outname))

def make_breakdown_graph(fname: str, outname: str):
    
    os.makedirs(IMGDIR, exist_ok=True)

    df = pd.read_csv(fname)
    names =df["Name"].astype(str).values
    IPC = df["IPC"].astype(float).values
    FE = df[L1Cycle.FRONTEND_BOUND.value].astype(float).values
    BE = df[L1Cycle.BACKEND_BOUND.value].astype(float).values
    BAD = df[L1Cycle.BAD_SPECULATION.value].astype(float).values
    RET = df[L1Cycle.RETIRING.value].astype(float).values
    
    fig, (ax1l, ax2l) = plt.subplots(1, 2, figsize=(10,5))

    ind = 0
    for i in range(len(names)): 
        if "comp-" in names[i]:
            ind = i
            break
    
    ax1r = ax1l.twinx()
    ax2r = ax2l.twinx()
    SIZE=2
    ax2r.plot(names[:ind], IPC[:ind], color="tab:red", 
        markerfacecolor="black", markersize=SIZE, markeredgecolor="black", linestyle="--", marker='o')

    ax2l.bar(names[:ind], FE[:ind], label="Frontend", color="tab:blue", edgecolor="black")
    ax2l.bar(names[:ind], BAD[:ind], bottom=FE[:ind], label="Bad Speculation", color="tab:orange", edgecolor="black")
    ax2l.bar(names[:ind], BE[:ind], bottom=FE[:ind]+BAD[:ind], label="Backend", color="tab:purple", edgecolor="black")
    ax2l.bar(names[:ind], RET[:ind], bottom=FE[:ind]+BAD[:ind]+BE[:ind], label="Retiring", color="tab:green", edgecolor="black")


    ax1r.plot(names[ind:], IPC[ind:], color="tab:red", markerfacecolor="black", 
        markeredgecolor="black", markersize=SIZE, linestyle="--", marker='o')

    ax1l.bar(names[ind:], FE[ind:], color="tab:blue",  edgecolor="black") # label="Frontend"
    ax1l.bar(names[ind:], BAD[ind:], bottom=FE[ind:], color="tab:orange", edgecolor="black") # , label="Bad Speculation"
    ax1l.bar(names[ind:], BE[ind:], bottom=FE[ind:]+BAD[ind:], color="tab:purple", edgecolor="black") # , label="Backend"
    ax1l.bar(names[ind:], RET[ind:], bottom=FE[ind:]+BAD[ind:]+BE[ind:], color="tab:green", edgecolor="black") # , label="Retiring"

    ax1l.set(ylim=(0, 100), ylabel="Cycle Breakdown (%)")
    ax2l.set(ylim=(0, 100), ylabel="Cycle Breakdown (%)")

    ax1r.set(ylim=(1, 2), ylabel="IPC")
    ax2r.set(ylim=(1, 2), ylabel="IPC")
    ax1r.yaxis.label.set_color("tab:red")
    ax2r.yaxis.label.set_color("tab:red")
    ax1r.tick_params(axis='y', colors="tab:red")
    ax2r.tick_params(axis='y', colors="tab:red")

    
    fig.legend(loc='upper center', ncol=4, fancybox=True, bbox_to_anchor=(0.5, 0.975))
    fig.tight_layout(pad=2)
    fig.subplots_adjust(right=0.9, top=0.88)
    fig.autofmt_xdate(bottom=0.3, rotation=45)
    # ax1.tick_params(rotation=45, axis='x')
    # ax2.tick_params(rotation=45, axis='x')

    plt.savefig(os.path.join(IMGDIR, outname))

if __name__ == "__main__":
    fpath=get_filepath()
    outpath_sfx="x86"
    if "arm" in fpath:
        outpath_sfx = "arm"
    
    if len(sys.argv) == 2:
        make_breakdown_graph(get_filepath(), f"breakdown-{outpath_sfx}")
    elif sys.argv[2] == "norm-mpki":
        make_normalized_MPKI_graph(get_filepath(), f"norm-MPKI-{outpath_sfx}")
    elif sys.argv[2] == "mpki":
        make_MPKI_graph(get_filepath(), f"MPKI-{outpath_sfx}")
    else:
        make_MR_graph(get_filepath(), f"MR-{outpath_sfx}")
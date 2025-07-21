#!/bin/python3
import sys
import os

NOT_IMPLEMENTED=-999


def get_filepath():

    if len(sys.argv) == 1:
        raise ValueError("Error: Mising file name.")

    fname = sys.argv[1]

    if not os.path.exists(fname):
        raise FileNotFoundError(fname)

    if os.path.isdir(fname):
        raise IsADirectoryError(fname)
    
    return fname

def get_group():
    if len(sys.argv) == 1:
        # raise ValueError("Error: cmd args missing group name.")
        return None
    
    return sys.argv[1]
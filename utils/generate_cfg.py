#!/bin/python3
"""
Requires environmental variable KUBE_CORES from .env to be set.
This can be done either by running a bash script that sources .env and then calls this python script, or by doing so manually in the command line.

Alternatively, one can simply set KUBE_CORES below to whatever the value in .env is.


"""
# Settable hyperparameters of sorts
# ===========================================================================
KUBE_CORES="0" 
MIN_LOADGEN_WORKERS = 20
POD_COUNT = {"monolith": 1, "microservices": 12, "mixed": 8}
DEFAULT_SCHEMES = ["monolith"] 
DEFAULT_CORES = [1]
# ===========================================================================

# +1 because of master
MIN_LOADGEN_CORES = 1 + MIN_LOADGEN_WORKERS

_SCHEME_NAMES = [k for k, _ in POD_COUNT.items()]

from typing import TypeAlias

Params: TypeAlias = tuple[tuple[int, int, int, int], tuple[int, int, int, int]]

# Of the form (SCALE_UTIL params, MIN_REPLICAS params)
# param 4-tup are of the form (CRITICAL, NONCRITICAL, TRIVIAL, FALLBACK)

BASIC_PARAMS: Params = ((60, 70, 80, 75), (3, 2, 1, 1))
DEFAULT_PARAMS: Params = ((75, 75, 75, 75), (1, 1, 1, 1))
AGGRO_PARAMS: Params = ((45, 60, 80, 75), (4, 2, 1, 1))
PARAMETERS: dict[str, Params] = {"basic": BASIC_PARAMS, "default": DEFAULT_PARAMS, "aggro": AGGRO_PARAMS}

def param_to_cfg(p : Params, delim: str ="\n") -> str:
    out =  f"CRITICAL_SCALE_UTIL={p[0][0]}{delim}"
    out += f"NONCRITICAL_SCALE_UTIL={p[0][1]}{delim}"
    out += f"TRIVIAL_SCALE_UTIL={p[0][2]}{delim}"
    out += f"FALLBACK_SCALE_UTIL={p[0][3]}{delim}"

    out += f"CRITICAL_MIN_REPLICAS={p[1][0]}{delim}"
    out += f"NONCRITICAL_MIN_REPLICAS={p[1][1]}{delim}"
    out += f"TRIVIAL_MIN_REPLICAS={p[1][2]}{delim}"
    out += f"FALLBACK_MIN_REPLICAS={p[1][3]}"
    return out


import os
import multiprocessing
import argparse
import shutil

# Instantiate the parser
parser = argparse.ArgumentParser(description='Generate config files for use in benchmarking various environments')
misc_group = parser.add_argument_group('misc')

parser.add_argument('-c', dest='cores', metavar='CORES', type=int, nargs='+', 
    help='Quantities of cores allocated to each replica.')

parser.add_argument('-m', '--max', metavar='REPLICAS', type=int, default=50, 
    help='Max number of replicas per group that will be benchmarked')

parser.add_argument('-l', dest='loadgen', metavar='WORKERS', type=int,
    default=MIN_LOADGEN_CORES, 
    help='Cores allocated to load generator workers. All other cores are allocated to OB')

parser.add_argument('-t', dest='type', default="default", choices=[k for k, _ in PARAMETERS.items()], help="some bonus scaling specific parameters that can be set. View source code of this file for more info.")

misc_group.add_argument('-p', dest='prune', action='store_true', help='Create cfgs/ dir if it does not already exist, and delete files within it if it does.')

misc_group.add_argument('-d', '--dry-run', dest='dry', action='store_true', 
    help='Print output instead of creating files.')

misc_group.add_argument('--display-args', action='store_true', help=argparse.SUPPRESS)


scheme_group = parser.add_argument_group('schemes').add_mutually_exclusive_group()

scheme_group.add_argument('-s', dest='scheme', nargs='+', choices=_SCHEME_NAMES,
    help='Specify specific fusion schemes to be benchmarked.')

scheme_group.add_argument('-A', dest='all_schemes', action='store_true', 
    help='Benchmark using all schemes.')

args = parser.parse_args()

schemes: list[str] = (_SCHEME_NAMES if args.all_schemes 
                      else args.scheme or DEFAULT_SCHEMES)

cores: list[int] = args.cores or DEFAULT_CORES

replicas: int = args.max
loadgen_cores: int = args.loadgen

if args.prune:
    DIRNAME = 'cfgs/'
    shutil.rmtree(DIRNAME, ignore_errors=True)
    os.makedirs(DIRNAME, exist_ok=True)

if args.display_args or args.dry:
    print("Argument values:")
    print(f"cores per replica: {cores}")
    # print(f"max replicas: {args.max}")
    print(f"loadgen cores: {args.loadgen}")
    print(f"schemes: {schemes}")
    print(f"type: {args.type}")
    if args.display_args:
        exit(0)

# the number of cores that have been allocated to kubernetes runtime.
def get_cores_alloced():
  alloc_str = os.getenv("KUBE_CORES", KUBE_CORES)
  alloced = 0

  splitted = alloc_str.split(",")
  for sub in splitted:
    bounds = sub.split("-")
    if len(bounds) == 1:
      alloced+=1
      continue

    # +1 because 0-1 => 0,1
    alloced+=int(bounds[1]) - int(bounds[0]) + 1
  
  return alloced


# the number of cores available to use for the application as a whole.
kube_cores = multiprocessing.cpu_count() - get_cores_alloced()

for scheme, pods in POD_COUNT.items():

    if scheme not in schemes:   # Are we benchmarking this scheme?
        continue

    for cores_per in set(cores):                          # Cores per fusion group
        
        
        out = f"SCHEME={scheme}\nLOADGEN_REPLICAS={loadgen_cores}\nOB_CORES={cores_per}\nOB_REPLICAS={replicas}\n"
        fname = f"cfgs/{scheme}_{cores_per:02d}_{replicas:02d}.cfg"
        out += param_to_cfg(PARAMETERS[args.type])
        
        if args.dry:
            print(f"{fname}: \t{out.replace("\n", ":")}")
        else:
            with open(fname, "w") as f:
                f.write(out)

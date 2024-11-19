#!/bin/python3
"""
Requires environmental variable KUBE_CORES from .env to be set.
This can be done either by running a bash script that sources .env and then calls this python script, or by doing so manually in the command line.

Alternatively, one can simply set DEFAULT_CORES below to whatever the value in .env is.


"""

DEFAULT_CORES="0"
import os
import multiprocessing

# the number of cores that have been allocated to kubernetes runtime.
def get_cores_alloced():
  alloc_str = os.getenv("KUBE_CORES", DEFAULT_CORES)

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
kube_cores = multiprocessing.cpu_count - get_cores_alloced()

for cores_per in [4,8,16]:
    for all_ob_cores in [1,2,4,8,16]:
        replicas = all_ob_cores // cores_per
        true_ob_cores = cores_per * replicas
        loadgen_cores = kube_cores - true_ob_cores

        if replicas == 0:
            continue
        out=f"""
LOADGEN_REPLICAS={loadgen_cores}
OB_CORES={cores_per}
OB_REPLICAS={replicas}
        """
        with open(f"cfgs/{cores_per:02d}_{replicas:02d}.cfg", "w") as f:
            f.write(out)

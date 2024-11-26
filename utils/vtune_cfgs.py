#!/bin/python3

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

# Settable
MIN_LOADGEN_WORKERS = 2
# +1 because of master
MIN_LOADGEN_CORES = 1 + MIN_LOADGEN_WORKERS

# the number of cores available to use for the application as a whole.
kube_cores = multiprocessing.cpu_count() - get_cores_alloced()

POD_COUNT={"monolith": 1, "microservices": 12, "mixed": 8}
print(kube_cores)

for cores_per in [1,2,3,6]:
    for scheme, pods in POD_COUNT.items():
        needed_cores = cores_per * pods
        loadgen_cores = kube_cores - needed_cores - 1

        if loadgen_cores < MIN_LOADGEN_CORES:
            continue
        
        out=f"""
LOADGEN_REPLICAS={loadgen_cores-1}
OB_CORES={cores_per}
OB_REPLICAS={1}
SCHEME={scheme}"""
        with open(f"cfgs/{scheme}_{cores_per:02d}.cfg", "w") as f:
            f.write(out)

# scripts

scripts that may be used by both user and runtime during load testing.
There should be little, if any, reliance on env variables set by the makefile.

- **export_allocations.sh**: copy `pod_stats.csv` files from `benchmark/out/<test_name>/stats` to `alloc/<test_name>.csv`
  - This will be used for static tests, wherein the number of replicas per group is kept constant throughout.
- **freq_scaling.sh**: sets all online cores to the performance frequency scaling governer. 
  - If a parameter is provided, i.e. `./scripts/freq_scaling.sh powersave`, that parameter is used as the governer instead.
- **get_cores.sh**: gets sum of utilization used by OB app.
- **get_replicas.sh**: gets total number of replicas, as well as their group's average cpu util and total cpu util. 
  - if any parameter is passed, i.e. `./scripts/get_replicas.sh 1`, the script will output in csv format instead of pretty-printing.
- **hyperthreading.sh**: Enables, disables, toggles, or reports the status of hyperthreading, depending on the parameters passed.
- **minikube_start.sh**: Starts minikube. If the env var `ALLOC_FILE` is not set, starts with `CPUManagerPolicy=static`. 
  - if it is set, core isolation is handled by pinning.sh
- **pinning.sh**: Pins root process of kubernetes runtime containers + current proc to env var `KUBE_CORES`, and gives each other container created by the benchmark it's own core. 
  - Loadgenerator pods are given cores first.
  - if any parameter is passed, i.e. `./scripts/pinning.sh 1`, the script will output current pod-core pairs without changing anything.
- **pull_stats_logging.sh**: deprecated.
- **pull_stats_quick.sh**: Get stats from the load generator while a test is still running
- **pull_stats.sh**: Ran for you by `make bench` and `make bench_all`. not actually intended to be ran on it's own.
- **stop.sh**: Deprecated, but removes all pods from the kubernetes cluster.
- **view_cpu_info.sh**: Prints pod:core pairings, and the utilization of that core, not just how much the pod is using.
- **checks/**: ran to see if things like hyperthreading, numa balance, etc. are set correctly.
- **cpu/**: Used by `get_cores.sh`

# Online Boutique

This repo contains a modified version of Service Weaver's [`Online
Boutique`][boutique] demo application, for the purpose of benchmarking.

[boutique]: https://github.com/ServiceWeaver/onlineboutique

to see some basic usage, run `make` in the root of the directory.

## Some dependencies:
- [go](https://go.dev/doc/install)
- [weaver](https://github.com/ServiceWeaver/weaver)
- [weaver-kube](https://github.com/ServiceWeaver/weaver-kube)
- [minikube](https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download#what-youll-need)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux)

## Additional Setup
- Change the `DOCKER` variable in Makefile to point to a docker account that you can push / pull images to and from
- Check the .yaml files in `release/base`, ensure that the resource allocations look good.
  - Something to consider: For a machine with, for example, 2 NUMA nodes, it would be best for the load generator to occupy the first node, and the actual application to occupy the second.
  - I originally deployed this on a machine with 20 cores per NUMA node, so in `release/base/loadgen.yaml` I set the master load generator to have one physical core allocated to it, the workers to have 1 core allocated to each of 18 replicas, and then the kubernetes runtime to have another core allocated to it.
    - This results in all Online Boutique containers deployed to be put in the second NUMA node.
    - For however many worker replicas you plan on creating, ensure that the `--expect-workers` flag in `src/loadgenerator/entrypoint.sh` is set to that number.
- To benchmark specific colocation schemes, in `make_scripts/bench_all.sh`, modify line 40 and write the specific schemes you want to use.
  - These schemes can be found in `release/base/colocation`
- Assuming `make bench_all` is used to run the benchmarks, the output should appear in the benchmark dir.
- The environment variable GOMAXPROCS=1 should be set for every component process, but currently this functionality is not implemented.

Note that most code is not production grade, and has not been thoroughly tested to work on every machine. If something breaks, let me know and I'll do my best to fix it.


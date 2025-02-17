# make_scripts/

scripts that are intended to be ran by makefile only, and not by the user.
Heavily relies on env variables set by the makefile, so these scripts are not of much real use otherwise.

- **bench_all.sh**: running `make bench_all` runs this file directly.
  - Runs a benchmark for each cfg file in `cfgs/`.
- **check_docker.sh**: Ensures that the user has set the `DOCKER` variable in `.env`, as otherwise when the build fails the error messages would be unhelpful.
- **check_env.sh**: Ensures that env variables have been set from a `*.cfg` file.
- **load_gen_yaml.sh**: Builds the deployment info for the loadgenerator from a template filled in with env variables
- **post_bench.sh**: imports latency info from loadgenerator container, fills in all the stats in the proper directory.
- **set_pod_replicas.sh**: Sets the exact number of replicas per deployment from a file in `alloc/`
  - This script is used if we are running a static test, i.e. the env variable `ALLOC_FILE` is set.
- **set_pod_scaling.sh**: Enables horizontal autoscaling for pods   
  - Used when we are NOT running a static test, i.e. the env variable `ALLOC_FILE` is NOT set.
- **weaver_gen_yaml.sh**: Builds the deployment info for the OB deployment from a set of templates filled in with env variables
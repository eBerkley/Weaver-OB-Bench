# Online Boutique

This repo contains a modified version of Service Weaver's [`Online Boutique`][boutique] demo application, for the purpose of benchmarking.

[boutique]: https://github.com/ServiceWeaver/onlineboutique

to see usage, run `make` in the root of the directory.

## Some dependencies:
- [go](https://go.dev/doc/install)
- python
- src/loadgenerator dependencies: `pip install -r src/loadgenerator/requirements.txt`
- A modified service weaver implementation is included as a submodule of this repository.

## Additional Setup
- This branch has not had as much development time as kube has had, and as such, some of the functionality is not fully implemented. Below is a list of *some* things this repo does not have yet:
  - A complete way to incrementally run every benchmark. Currently, the file `release/generated/weaver.toml` must be written to manually.
  - Some of the scripts and makefile recipes have not been updated.
  - CPU utilization is not captured.
  - Benchmark results are not automatically moved to a convenient folder.

- Like the kube branch, GOMAXPROCS should be set to 1, but currently this functionality is not implemented yet. However, it should be able to be done by simply adding the line
  ``` toml
  env = ["GOMAXPROCS=1"]
  ```
  to `release/generated/weaver.toml` below the [serviceweaver] section.

- Note: the service weaver submodule has been modified to support pinning each component group to a specific CPU core / NUMA node. An example of the syntax to do this is in `release/generated/weaver.toml`. Note that as a result of this using linux's cgroup functionality, you will likely have to deploy the application using sudo.

Note that most code is not production grade, and has not been thoroughly tested to work on every machine. If something breaks, let me know and I'll do my best to fix it.

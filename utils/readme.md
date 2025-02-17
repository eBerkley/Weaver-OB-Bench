# utils/

Files containing scripts that are intended to be ran only by the user, 
Either before a benchmark to generate configs, 
or to run a separate kind of test entirely (currently, just vtune profiling).

- **analyze.sh**: Prints info about vtune profiling reports.
- **generate_cfg.py**: Populates `cfgs/` with different config files to be used with `make bench_all`. 
  - run `./utils/generate_cfg.py -h` for more info.
- **report.sh**: generates a user-specified report from a vtune profile result.
- **vtune_cfgs.py**: Currently deprecated.
- **vtune.sh**: Starts a new benchmark and runs vtune profiling on each pod.
- **watcher_paired.sh**: deprecated.
- **watcher.sh**: deprecated.

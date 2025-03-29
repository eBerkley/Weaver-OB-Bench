# Bench Types

For the sake of not having to swap out env vars repeatedly, BENCH_TYPE can be used to programmatically set the necessary env variables to achieve the needed functionality.

typically, you will be calling either bench or bench_all.

In addition to setting the variable in .env, one can also invoke make with the var set, i.e.
```bash
make BENCH_TYPE=INITIAL bench
```

## Custom

Prevent any env variables from being overloaded. 

```conf
BENCH_TYPE=CUSTOM
```

## Initial

Create a fully distributed deployment, each component gets one replica, each replica gets one core.

We provide a light, constant load to determine a SLO target based on each component's p50 service latency. 

These values are then saved for later benchmark types.

```conf
BENCH_TYPE=INITIAL
LOCUST_SHAPE=constload

INITIAL_RUNTIME=<seconds>
INITIAL_USERS=<number_of_users>
```

## Fixed

Create a fully distributed deployment in which one component is *fixed*, while others are dynamic. 

The fixed component is given one replica, and it's horizontal pod autoscaler is disabled. The fixed component's replica is allocated a large number of cores.

All other components are given one replica with the HPA enabled. Each replica gets one core. 


```conf
BENCH_TYPE=FIXED

# .cfg
FIXED=<component_name>
FIXED_HEIGHT=<cores_allocated>

```

## Instruction Footprint Profiling

All components are profiled by perf to extract their instruction footprint.

```conf
BENCH_TYPE=INST_FP

```

# Bench Types

## Initial

Create a fully distributed deployment, each component gets one replica, each replica gets one core.

We provide a light, constant load to determine a SLO target based on each component's max p50 latency. 

These values are then saved for later benchmark types.

```bash
BENCH_TYPE=INITIAL
LOCUST_SHAPE=constload

# .cfg
OB_REPLICAS=1

INITIAL_RUNTIME=<seconds>
LOCUST_CONST_USERS=<number_of_users>
```

## Fixed

Create a fully distributed deployment in which one component is *fixed*, while others are dynamic. 

The fixed component is given one replica, and it's horizontal pod autoscaler is disabled. The fixed component's replica is allocated a large number of cores.

All other components are given one replica with the HPA enabled. Each replica gets one core. 


```bash
BENCH_TYPE=FIXED

# .cfg
FIXED=<component_name>
FIXED_HEIGHT=<cores_allocated>

```



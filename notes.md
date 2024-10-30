
# notes

## vpa methodology

put vpa yaml in base, add the --cpu-integer-post-processor-enabled=true arg

weaver kube deploy ...
get all container names from gen.yaml

add vpa-post-processor.kubernetes.io/{containerName}_integerCPU=true annotations to vpa yaml
deploy

## Requirements

We should probably fork. what I have in mind is this:

1. Set min and max CPUs per replica for each group
2. set max total OB cores

then at runtime:

1. Start every group out with 1 replica, one CPU per group
2. as utilization grows, scale up each replica by adding cores
3. once we are at that 65% number on average, and hit the max cpu per replica, add a new replica with just one core

repeat 2-3, note that we'll only be scaling up one replica at a time

## Get container name

```bash
kubectl get po --selector=serviceweaver/app=ob -o jsonpath="{.items[*].spec.containers[*].name}"
```



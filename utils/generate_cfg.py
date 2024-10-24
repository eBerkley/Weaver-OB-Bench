kube_cores = 29


for cores_per in [4,8,16]:
    for all_ob_cores in [1,2,4,8,16]:
        replicas = all_ob_cores // cores_per
        true_ob_cores = cores_per * replicas
        loadgen_cores = kube_cores - true_ob_cores

        if replicas == 0:
            continue
        out=f"""LOADGEN_REPLICAS={loadgen_cores}
DOCKER=docker.io/dmquinn
OB_CORES={cores_per}
OB_REPLICAS={replicas}
LOCUST_SHAPE=rampload
        """
        with open(f"cfgs/{cores_per:02d}_{replicas:02d}.cfg", "w") as f:
            f.write(out)

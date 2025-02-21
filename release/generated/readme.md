# release/generated

Files generated in the process of deploying the application + loadgenerator to a kubernetes cluster.

- **gen.yaml**: The finalized yaml that is passed to kubernetes to deploy the OB application.
- **groups.yaml**: The file containing concrete info on each OB pod that will be deployed.
- **kube.yaml**: The result of combining **base/kube.yaml** with **groups.yaml**. Passed to weaver-kube to create **gen.yaml**
- **loadgen.yaml**: The finalized yaml that is passed to kubernetes to deploy the loadgenerator.
- **ob** The binary that the OB pods run.
- **version.txt**: The docker container version that both OB and the loadgenerator run.
- **weaver.toml** Says where to find the OB binary.

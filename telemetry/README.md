# SocialWeaver/telemetry

Prototype for a runtime that collects data regarding the performance of the application from *within* the cluster, instead of outside. 

Still very much a WIP, features a lot of unused code that could be used to collect data from Jaeger, or get replica count info. 
Currently, the only code that is actually ran is to get the `E2E` metrics from prometheus.

Codebase here is largely unstructured.
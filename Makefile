.EXPORT_ALL_VARIABLES:
TOP := .
include auto/paths.mk

WEAVER_KUBE ?= ./weaver-kube/cmd/weaver-kube/weaver-kube # weaver-kube
WEAVER ?= ./weaver/cmd/weaver/weaver # weaver
TELEMETRY_TRACES ?= ./weaver-kube/examples/telemetry-traces/telemetry-traces
TELEMETRY_METRICS ?=./weaver-kube/examples/telemetry-metrics/telemetry-metrics

SHELL := /bin/bash
CONFIG_FILE ?= CONFIG.cfg

# sets DOCKER, KUBE_CORES, LOCUST_SHAPE, SCHEME
include .env 

# sets LOADGEN_REPLICAS, OB_CORES, OB_REPLICAS, and optionally SCHEME.
include $(CONFIG_FILE)

ifeq ($(VERBOSE), 1)
	DEBUG_OUTPUT := $(LOGS_FILE)
else
	DEBUG_OUTPUT := /dev/null
endif

TRACE_ENABLE := false
METRIC_ENABLE := false

.PHONY: all clean minikube_start minikube_restart check_smt toggle_smt deploy bench bench_all stop clear_logs check_docker check_loadgen pre_deploy bench_once 

all:
	@echo valid arguments:
	@echo
	@echo "minikube_[re]start   - [re]start minikube"
	@echo "check_smt            - View if hyperthreading is enabled"
	@echo "toggle_smt           - Toggle hyperthreading. NOTE: May require root."
	@echo "deploy               - Starts minikube / builds new version of app if necessary, then deploys."
	@echo "pre_deploy           - Builds new version of app, but does not deploy anything."
	@echo "bench                - Deploys app, and runs script to collect metrics and terminate when load test is complete."
	@echo "bench_all            - Run benchmark using every colocation scheme in release/base/colocation"
	@echo "stop                 - remove deployments"


include auto/scripts.mk


check_loadgen: $(LOAD_SRC_PY)
	@python3 -m py_compile $(LOAD_SRC_PY)


# Update the release/generated/*.yaml files based on config env vars.
# Check to make sure all the prerequisites for deploy execute properly. 
# Does not actually deploy anything.
# check_docker should prevent gen yaml scripts from firing without `$$DOCKER` being set.
pre_deploy: check_docker check_loadgen $(WEAVER_GEN_YAML) $(LOAD_GEN_YAML)
	@./make_scripts/check_env.sh
	@./scripts/checks/check_freq_scaling.sh
	@./scripts/checks/check_hyperthreading.sh
	@./scripts/checks/check_numa_balance.sh
	
	@echo 																															| tee -a $(LOGS_FILE)
	@echo "bench type:                    $$BENCH_TYPE"									| tee -a $(LOGS_FILE)
	@echo "scheme:                        $$SCHEME"											| tee -a $(LOGS_FILE)
	@echo "cscheme:                       $$C_SCHEME"										| tee -a $(LOGS_FILE)
	@echo "loadshape:                     $$LOCUST_SHAPE"								| tee -a $(LOGS_FILE)
	@echo "loadgenerator workers:         $$LOADGEN_REPLICAS"						| tee -a $(LOGS_FILE)
	@echo "max replicas per fusion group: $$OB_REPLICAS" 								| tee -a $(LOGS_FILE)
	@echo "VERBOSE, DEBUG_OUTPUT:         $$VERBOSE, $(DEBUG_OUTPUT)" 	| tee -a $(LOGS_FILE)
	@echo 																															| tee -a $(LOGS_FILE)
	
	@echo pre deploy check / code gen complete.



# release/generated/gen.yaml and release/generated/loadgen.yaml
deploy: minikube_start pre_deploy
	@echo deploying onlineboutique, loadgenerator...| tee -a $(LOGS_FILE)
	@# Remove any old deployment.
	@-kubectl delete all --all >>$(LOGS_FILE) 2>&1
	@if [ "$(TRACE_ENABLE)" = "true" ]; then \
		echo "Jaeger is enabled, starting to collect trace" ; \
	    kubectl apply -f $(JAEGER_TRACE_YAML) >> $(DEBUG_OUTPUT) 2>&1; \
	else \
	    echo "Skipping Jaeger deployment." >> $(DEBUG_OUTPUT); \
	fi
	@if [ "$(METRIC_ENABLE)" = "true" ]; then \
		echo "prometheus is enabled, starting to collect metrics" ; \
	    kubectl apply -f $(PROMETHEUS_METRIC_YAML) >> $(DEBUG_OUTPUT) 2>&1; \
	else \
	    echo "Skipping prometheus deployment." >> $(DEBUG_OUTPUT); \
	fi
	@echo creating loadgenerator... >> $(LOGS_FILE)
	@kubectl apply -f $(LOAD_GEN_YAML) >> $(LOGS_FILE) 2>&1
	@echo creating OB ... >> $(LOGS_FILE)
	@kubectl apply -f $(WEAVER_GEN_YAML) >> $(LOGS_FILE) 2>&1
	@# If we need to pin, we wait a while because it takes a min to start up.
	@if [[ -n $$ALLOC_FILE ]]; then sleep 25; ./scripts/pin_pods.sh | tee -a $(LOGS_FILE); fi


# Can be run by user 
# Used to benchmark app under environment specified by env vars
bench: deploy	
	./scripts/pull_stats.sh 
	@echo deleting deployment...
	@-kubectl delete all --all >> $(DEBUG_OUTPUT) 2>&1
	@./make_scripts/post_bench.sh

# Shouldn't be ran by user, used by bench_all.
bench_once: deploy
	./scripts/pull_stats.sh

bench_trace: deploy
	./scripts/traces_stats.sh
	@echo deleting deployment...

bench_metric: deploy
	./scripts/metrics_stats.sh
	@echo deleting deployment...

# ./bench_all changes $(WEAVER_GEN_YAML) every time it runs, 
# 	new images built each time.
bench_all: clear_logs
	@echo 
	./make_scripts/bench_all.sh
# make bench_all with traces collection turn on
bench_trace_all: $(TELEMETRY_TRACES)
	$(MAKE) bench_all TRACE_ENABLE=true
# make bench_all with metrics collection turn on
bench_metric_all: $(TELEMETRY_METRICS)
	$(MAKE) bench_all METRIC_ENABLE=true

$(WEAVER):
	go build -C weaver/cmd/weaver

$(WEAVER_KUBE): 
	go build -C weaver-kube/cmd/weaver-kube

$(TELEMETRY_TRACES): $(WEAVER_KUBE)
	(cd weaver-kube/examples/telemetry-traces && go build -o telemetry-traces .)
	mv ./weaver-kube/examples/telemetry-traces/telemetry-traces $(WEAVER_BIN_PATH)

$(TELEMETRY_METRICS):$(WEAVER_KUBE)
	(cd weaver-kube/examples/telemetry-metrics && go build -o telemetry-metrics .)
	mv ./weaver-kube/examples/telemetry-metrics/telemetry-metrics $(WEAVER_BIN_PATH)

# if deployment specifications or src code was modified,
# 	Update Weaver kubernetes yaml
# 	modifies version file, which should trigger LOAD_GEN_YAML
$(WEAVER_GEN_YAML): $(KUBE_BASE_YAML) $(BIN) $(CONFIG_FILE) .env
	@echo rebuilding onlineboutique container...
	@if [ -z $$ALLOC_FILE ]; then \
		echo "pods=dynamic"; \
		./make_scripts/set_pod_scaling.sh; \
	else \
		echo "pods=static"; \
		./make_scripts/set_pod_replicas.sh; \
	fi
	@./make_scripts/set_pod_resources.sh
	@if [ "$(TRACE_ENABLE)" = "true" ]; then \
	    echo "Jaeger is employed to collect trace, telemetry-traces is running"; \
	    ./make_scripts/weaver_gen_yaml.sh telemetry-traces; \
	elif [ "$(METRIC_ENABLE)" = "true" ]; then \
	    echo "Prometheus is employed to collect metrics, telemetry-metrics is running"; \
	    ./make_scripts/weaver_gen_yaml.sh telemetry-metrics; \
	else \
	    ./make_scripts/weaver_gen_yaml.sh weaver-kube; \
	fi

# if deployment specifications or loadgen code was modified, 
#	Update Load Generator
$(LOAD_GEN_YAML): $(LOAD_SRC_ALL) $(VERSION_FILE) $(LOAD_BASE_YAML) $(CONFIG_FILE) .env
	@echo rebuilding loadgenerator container...
	@./make_scripts/load_gen_yaml.sh

# If src code was modified, 
#	Update binary
$(BIN): $(MAIN_SRC)
	@echo rebuilding binary...
	
	@cd $(SRC); ../$(WEAVER) generate ./...; go build -o ../release/generated; cd ..
	@mv release/generated/Weaver-OB-Bench release/generated/ob


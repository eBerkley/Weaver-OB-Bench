.EXPORT_ALL_VARIABLES:
TOP := .
include auto/paths.mk

WEAVER_KUBE ?= ./weaver-kube/cmd/weaver-kube/weaver-kube # weaver-kube
WEAVER ?= ./weaver/cmd/weaver/weaver # weaver

SHELL := /bin/bash
CONFIG_FILE ?= CONFIG.cfg

include .env 
include locust.env
include docker.env

# sets LOADGEN_REPLICAS, OB_CORES, OB_REPLICAS, and optionally SCHEME.
include $(CONFIG_FILE)

ifeq ($(VERBOSE), 1)
	DEBUG_OUTPUT := $(LOGS_FILE)
else
	DEBUG_OUTPUT := /dev/null
endif

# Override env variables

ifeq ($(BENCH_TYPE), STATIC)
	METRIC_ENABLE   := false
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE          := slo_rampload
	LOCUST_LOW_LOAD_USERS := $(STATIC_LOW_LOAD_USERS)

else ifeq ($(BENCH_TYPE), INITIAL)
	METRIC_ENABLE   := true
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE 			 := constload
	LOCUST_CONST_USERS := $(INITIAL_USERS)

else ifeq ($(BENCH_TYPE), FIXED)
	METRIC_ENABLE   := true
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := true
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE := slowerload
	LOCUST_SLOWLOAD_RAMP := $(FIXED_USERS_RAMP)
	LOCUST_RAMP_RATE := $(FIXED_USERS_RAMP_RATE)

else ifeq ($(BENCH_TYPE), HETERO_HT)
	METRIC_ENABLE   := true
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE := slowerload
	LOCUST_SLOWLOAD_RAMP := $(FIXED_USERS_RAMP)
	LOCUST_RAMP_RATE := $(FIXED_USERS_RAMP_RATE)

else ifeq ($(BENCH_TYPE), INST_FP)
	METRIC_ENABLE   := false
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := true
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE 			 := constload
	LOCUST_CONST_USERS := $(INST_FP_USERS)

else ifeq ($(BENCH_TYPE), CPU_UTIL)
	METRIC_ENABLE   := false
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := true
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_SHAPE       := constload
	LOCUST_CONST_USERS := $(CPU_UTIL_USERS)

else # ifeq ($(BENCH_TYPE), CUSTOM)
# ...
endif


.PHONY: all clean minikube_start minikube_restart check_smt toggle_smt deploy bench bench_all stop clear_logs check_docker check_loadgen pre_deploy bench_once bin_build

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

path_init:
	@echo "Initializing project setup..."
	@if [ ! -d "$(WEAVER_BIN_PATH)" ]; then \
		mkdir -p "$(WEAVER_BIN_PATH)"; \
		echo "Created $(WEAVER_BIN_PATH)"; \
	fi
	@grep -qxF 'export PATH="$$PATH:$(WEAVER_BIN_PATH)"' $(HOME)/.bashrc || \
		echo 'export PATH="$$PATH:$(WEAVER_BIN_PATH)"' >> $(HOME)/.bashrc && \
		echo "Added $(WEAVER_BIN_PATH) to PATH in ~/.bashrc"
	@echo "Setup complete. Run 'source ~/.bashrc' or restart your terminal to activate changes."


test_envvars:
	@echo "BENCH_TYPE         : $$BENCH_TYPE"
	@echo "METRIC_ENABLE      : $$METRIC_ENABLE"
	@echo "TRACE_ENABLE       : $$TRACE_ENABLE"
	@echo "INSTFP_ENABLE      : $$INSTFP_ENABLE"
	@echo "CPU_UTIL_ENABLE    : $$CPU_UTIL_ENABLE"
	@echo "VERTICAL_PROF      : $$VERTICAL_PROF"
	@echo "LOCUST_SHAPE       : $$LOCUST_SHAPE"
	@echo "LOCUST_CONST_USERS : $$LOCUST_CONST_USERS"

check_loadgen: $(LOAD_SRC_PY)
	@python3 -m py_compile $(LOAD_SRC_PY)


# Update the release/generated/*.yaml files based on config env vars.
# Check to make sure all the prerequisites for deploy execute properly. 
# Does not actually deploy anything.
# check_docker should prevent gen yaml scripts from firing without `$$DOCKER` being set.
pre_deploy: check_docker check_loadgen bin_build $(WEAVER_GEN_YAML) $(LOAD_GEN_YAML)
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
	@echo creating loadgenerator... >> $(LOGS_FILE)
	@kubectl apply -f $(LOAD_GEN_YAML) >> $(LOGS_FILE) 2>&1
	@echo creating OB ... >> $(LOGS_FILE)
	@kubectl apply -f $(WEAVER_GEN_YAML) >> $(LOGS_FILE) 2>&1
	sleep 10
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

	@# If we need to pin, we wait a while because it takes a min to start up.
	@if [[ -n $$ALLOC_FILE ]]; then sleep 25; ./scripts/pin_pods.sh | tee -a $(LOGS_FILE); fi


# Can be run by user 
# Used to benchmark app under environment specified by env vars
bench: deploy	

	@if [[ $$RUNTIME_METRIC_ENABLE = "true" ]]; then \
		./scripts/runtime_metrics_stats.sh;        \
	elif [[ $$TRACE_ENABLE = "true" ]]; then    \
		./scripts/trace_stats.sh;                 \
	elif [[ $$INSTFP_ENABLE = "true" ]]; then   \
		./scripts/instfp_stats.sh $(TOP);         \
	elif [[ $$CPU_UTIL_ENABLE = "true" ]]; then \
		./scripts/cpu_util_stats.sh;              \
	elif [[ $$VERTICAL_PROF = "true" ]]; then   \
		./scripts/vertical_pull_stats.sh;         \
	elif [[ $$METRIC_ENABLE = "true" ]]; then   \
		./scripts/metrics_stats.sh;               \
	else                                        \
		./scripts/pull_stats.sh;                  \
	fi

	@echo deleting deployment...
	@-kubectl delete all --all >> $(DEBUG_OUTPUT) 2>&1

# Shouldn't be ran by user, used by bench_all.
bench_once: deploy
	./scripts/pull_stats.sh

# ./bench_all changes $(WEAVER_GEN_YAML) every time it runs, 
# 	new images built each time.
bench_all: clear_logs
	@echo 
	./make_scripts/bench_all.sh

WEAVER_DIR := $(TOP)/weaver
WEAVER_SRC := $(shell find $(WEAVER_DIR) -type f -name '*.go')
$(WEAVER): $(WEAVER_SRC)
	go build -C weaver/cmd/weaver

KUBE_DIR   := $(TOP)/weaver-kube
KUBE_SRC   := $(shell find $(KUBE_DIR) -type f -name '*.go')
KUBE_BIN   := $(WEAVER_BIN_PATH)/weaver-kube
TRACE_BIN  := $(WEAVER_BIN_PATH)/telemetry-traces
METRIC_BIN := $(WEAVER_BIN_PATH)/telemetry-metrics

$(KUBE_BIN): $(KUBE_SRC)
	go build -C weaver-kube/cmd/weaver-kube
	cp ./weaver-kube/cmd/weaver-kube/weaver-kube $(WEAVER_BIN_PATH)

$(TRACE_BIN): weaver-kube/examples/telemetry-traces/main.go $(KUBE_SRC)
	(cd weaver-kube/examples/telemetry-traces && go build -o telemetry-traces .)
	cp ./weaver-kube/examples/telemetry-traces/telemetry-traces $(WEAVER_BIN_PATH)

$(METRIC_BIN): weaver-kube/examples/telemetry-metrics/main.go $(KUBE_SRC)
	(cd weaver-kube/examples/telemetry-metrics && go build -o telemetry-metrics .)
	cp ./weaver-kube/examples/telemetry-metrics/telemetry-metrics $(WEAVER_BIN_PATH)

#rebuild the binary if weaver kube src was modified
bin_build: $(KUBE_BIN) $(TRACE_BIN) $(METRIC_BIN)

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


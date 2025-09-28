.EXPORT_ALL_VARIABLES:
TOP := .
include auto/paths.mk

WEAVER_KUBE ?= ./weaver-kube/cmd/weaver-kube/weaver-kube # weaver-kube
WEAVER ?= ./weaver/cmd/weaver/weaver # weaver

SHELL := /bin/bash
CONFIG_FILE ?= CONFIG.cfg

INIT_VERSION=v0.0.20

include .env 
include locust.env
include docker.env

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

	LOCUST_SHAPE 			 := slowerload
	LOCUST_SLOWLOAD_RAMP := $(FIXED_USERS_RAMP)
	LOCUST_RAMP_RATE := $(FIXED_USERS_RAMP_RATE)

else ifeq ($(BENCH_TYPE), FIXED)
	METRIC_ENABLE   := true
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := true
	RUNTIME_METRIC_ENABLE := true

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

else ifeq ($(BENCH_TYPE), ALLOC)
	METRIC_ENABLE   := false
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_RESET_CONN := 1

	LOCUST_SHAPE         := slowerload
# 	LOCUST_SHAPE         := constload
	LOCUST_CONST_USERS   := 2500
	LOCUST_SLOWLOAD_RAMP := 1000
	LOCUST_SLOWER_PAUSE  := 45
	LOCUST_WAIT_TIME     := 400		

else ifeq ($(BENCH_TYPE), PERF)
	METRIC_ENABLE   := false
	TRACE_ENABLE    := false
	INSTFP_ENABLE   := false
	CPU_UTIL_ENABLE := false
	VERTICAL_PROF   := false
	RUNTIME_METRIC_ENABLE := false

	LOCUST_RESET_CONN := 0
	LOCUST_SHAPE       := constload
# LOCUST_CONST_USERS = MAKE_USER_SCALE * M-replicas in SCHEME
# MAKE_USER_SCALE    := 1300
#	LOCUST_CONST_USERS := $(shell ./make_scripts/adjust_load.sh $(SCHEME) $(MAKE_USER_SCALE))
   	LOCUST_CONST_USERS := 15000
	VTUNE_DURATION     := 300
else # ifeq ($(BENCH_TYPE), CUSTOM)
# ...
endif


.PHONY: all clean k3s_start minikube_restart check_smt toggle_smt deploy bench bench_all stop clear_logs check_docker check_loadgen pre_deploy bench_once bin_build

all:
	@echo valid arguments:
	@echo
# 	@echo "minikube_[re]start   - [re]start minikube"
	@echo "check_smt            - View if hyperthreading is enabled"
	@echo "toggle_smt           - Toggle hyperthreading. NOTE: May require root."
	@echo "deploy               - Starts minikube / builds new version of app if necessary, then deploys."
	@echo "pre_deploy           - Builds new version of app, but does not deploy anything."
	@echo "bench                - Deploys app, and runs script to collect metrics and terminate when load test is complete. Mostly deprecated."
	@echo "bench_all            - Run benchmark using every file in cfgs/"
	@echo "stop                 - remove deployments"
	@echo "analyze S=<scheme>   - pretty-print results for <scheme>"
	@echo "results S=<scheme>   - extract results for <scheme> and populate benchmarks/results/<scheme>.csv"
	@echo "results_all          - run \`make results S=<scheme>\` for all newly benchmarked schemes"


include auto/scripts.mk


status:
	./utils/print_status.sh

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
	@echo "connection pooling:            $$LOCUST_CONN_POOL"						| tee -a $(LOGS_FILE)
	@echo "max replicas per fusion group: $$OB_REPLICAS" 								| tee -a $(LOGS_FILE)
	@echo "VERBOSE, DEBUG_OUTPUT:         $$VERBOSE, $(DEBUG_OUTPUT)" 	| tee -a $(LOGS_FILE)
	@echo "CheckoutService type:          $$CHECKOUT_FUNCTIONALITY"     | tee -a $(LOGS_FILE)
	@echo 																															| tee -a $(LOGS_FILE)
	
	@echo pre deploy check / code gen complete.

# Couldn't find a better way to do this
define REDIS_CONFIG
	maxmemory 400mb 
	maxmemory-policy allkeys-lru
endef

deploy_prod_redis:
	@if [[ -z "$(shell helm list --no-headers | awk '{print $$1}' | grep prod-redis)" ]]; then \
		helm install prod-redis bitnami/redis -f release/aux/helm/redis.yaml \
			--set commonConfiguration="$$REDIS_CONFIG" \
			--set global.security.allowInsecureImages=true \
			--set replica.replicaCount=4 \
			--set global.defaultStorageClass=local-path \
			--set master.persistence.enabled=false \
			--set replica.persistence.enabled=false \
			--set auth.enabled=false \
			--set master.resources.requests.cpu=1 \
			--set master.resources.limits.cpu=1 \
			--set master.resources.requests.memory=1Gi \
			--set master.resources.limits.memory=1Gi \
			--set replica.resources.requests.cpu=1 \
			--set replica.resources.limits.cpu=1 \
			--set replica.resources.requests.memory=1Gi \
			--set replica.resources.limits.memory=1Gi \
			--timeout 15m \
			--wait; \
		fi

# 	@if [[ -z "$(shell helm list --no-headers | awk '{print $$1}' | grep prod-redis)" ]]; then \
# 		helm install prod-redis bitnami/redis-cluster -f release/aux/redis-cluster.yaml \
# 			--set cluster.nodes=6 \
# 			--set cluster.replicas=1 \
# 			--set global.defaultStorageClass=local-path \
# 			--set persistence.enabled=false \
# 			--set usePassword=false \
# 			--set redis.resources.requests.cpu=1 \
# 			--set redis.resources.limits.cpu=1 \
# 			--set redis.resources.requests.memory=1Gi \
# 			--set redis.resources.limits.memory=1Gi \
# 			--timeout 15m \
# 			--wait; \
# 	fi

rebuild_init: regen_prod_db
	docker build . -f src/productcatalogservice/product_gen/Dockerfile \
	 	--build-arg BASE_DIR=src/productcatalogservice \
		-t docker.io/eberkley/ob-mongo-init:$(INIT_VERSION) && \
		docker push docker.io/eberkley/ob-mongo-init:$(INIT_VERSION)

# only do anything if the name 'mongo' is NOT found by helm
# An explanation on these settings:
# Requests and limits are set manually so that pods that receive traffic are in 'Guaranteed' QoS class.
# Shards=2 is static, shardsvc.dataNode.replicaCount=3 is static, all other replica counts are dynamic.
# We enable scaling out on both mongos and datanodes, which is not functionality provided by the chart originally.
# To do this, we do the following:
#		modify the dataNode yamls to give statefulsets a label that identifies their shard
# 	Add three HPAs: one for mongos, and one for each shard.
#		Set the service pointing to mongos instances to a headless service
#		Use the `mongodb+srv` connection string type so that mongodb clients are aware of new mongos instances
# 	Set readPreference=nearest for all clients, since it is a read-only but frequently accessed database.
#  		kubectl apply -f release/aux/mongo-hpa.yaml && 
# --set global.defaultStorageClass=local-path
# 		helm install mongo bitnami/mongodb-sharded -f release/aux/mongo.yaml
deploy_mongo:
	@if [[ -z "$(shell helm list --no-headers | awk '{print $$1}' | grep mongo)" ]]; then \
		helm install mongo ./release/aux/helm/mongodb-sharded -f release/aux/helm/mongo.yaml \
			--set configsvr.persistence.enabled=false \
			--set shardsvr.persistence.enabled=false \
			--set global.security.allowInsecureImages=true \
			--set shards=2 \
			--set shardsvr.dataNode.replicaCount=2 \
			--set mongos.replicaCount=2 \
			--set auth.rootPassword=productDB \
			--set configsvr.replicaCount=3 \
			--set configsvr.resources.requests.cpu=25m \
			--set configsvr.resources.limits.cpu=25m \
			--set configsvr.resources.requests.memory=1Gi \
			--set configsvr.resources.limits.memory=1Gi \
			--set mongos.resources.requests.cpu=1 \
			--set mongos.resources.limits.cpu=1 \
			--set mongos.resources.requests.memory=2Gi \
			--set mongos.resources.limits.memory=2Gi \
			--set shardsvr.dataNode.resources.requests.cpu=1 \
			--set shardsvr.dataNode.resources.limits.cpu=1 \
			--set shardsvr.dataNode.resources.requests.memory=2Gi \
			--set shardsvr.dataNode.resources.limits.memory=2Gi \
			--set service.clusterIP=None \
			--timeout 15m \
			--wait && \
		./scripts/restore_mongo.sh; \
	fi


debug_mongo:
# 	@echo 'mongosh admin --host mongo-mongodb-sharded --authenticationDatabase admin -u root -p productDB'
	@echo mongosh 'mongodb+srv://root:productDB@mongo-mongodb-sharded.default.svc.cluster.local/product-db?tls=false&authSource=admin&readPreference=nearest'
	@kubectl run --namespace default mongo-debug --rm -it --restart='Never' \
		--image docker.io/eberkley/ob-mongo-init:$(INIT_VERSION) \
		--image-pull-policy='IfNotPresent' \
		--command bash

regen_prod_db:
	@-rm -rf dump/product-db
	@cd src/productcatalogservice/product_gen && go build && ./product_gen



delete_mongo:
	-@if [[ -n "$(shell helm list --no-headers | awk '{print $$1}' | grep mongo)" ]]; then \
		helm uninstall mongo; \
		kubectl delete -f release/aux/mongo-hpa.yaml; \
		kubectl delete pvc --selector=app.kubernetes.io/instance=mongo; \
	fi

delete_load:
	-@kubectl delete deploy --selector=app=loadgenerator
	-@kubectl delete deploy --selector=role=loadgenerator-worker
	-@kubectl delete svc --selector=app=loadgenerator

delete_app: 
	-@kubectl delete deploy --selector=serviceweaver/app=ob
	-@kubectl delete configmap --selector=serviceweaver/app=ob
	-@kubectl delete hpa --selector=serviceweaver/app=ob
	-@kubectl delete svc --selector=serviceweaver/app=ob

	-@kubectl delete svc --selector=app=cart-redis
	-@kubectl delete configmap --selector=app=cart-redis
	-@kubectl delete deploy --selector=app=cart-redis

# 	-@kubectl delete svc --selector=app=product-redis
# 	-@kubectl delete configmap --selector=app=product-redis
# 	-@kubectl delete deploy --selector=app=product-redis

delete_all: delete_load delete_app delete_mongo

# -f release/aux/helm/jaeger.yaml 
# --set storage.type=memory 
# --set collector.cmdlineParams.collector.queue-size="5000" 
# 	This is being set in helm/jaeger rn

deploy_jaeger:
	@if [[ "$(TRACE_ENABLE)" = "true" ]] && [[ -z "$(shell helm list --no-headers | awk '{print $$1}' | grep jaeger)" ]]; then \
		echo "jaeger is enabled, deploying jaeger"; \
		helm install jaeger jaegertracing/jaeger \
			-f release/aux/helm/jaeger.yaml \
			--set collector.replicaCount=2 \
			--set provisionDataStore.elasticsearch=true \
			--set provisionDataStore.cassandra=false \
			--set storage.type=elasticsearch \
			--set elasticsearch.master.masterOnly=true \
			--set elasticsearch.master.replicaCount=2 \
			--set elasticsearch.ingest.replicaCount=1 \
			--set elasticsearch.data.replicaCount=2 \
			--set elasticsearch.coordinating.replicaCount=1 \
			--set collector.service.otlp.http.name="otlp-http" \
			--set collector.service.otlp.http.port="4318" \
			--set collector.service.otlp.grpc.name="otlp-grpc" \
			--set collector.service.otlp.grpc.port="4317" \
			--timeout 15m \
			--wait; \
	fi

# release/generated/gen.yaml and release/generated/loadgen.yaml
deploy: delete_load delete_app pre_deploy deploy_mongo deploy_prod_redis
	@echo deploying onlineboutique, loadgenerator...| tee -a $(LOGS_FILE)
	@# Remove any old deployment.
# 	@-kubectl delete all --all >>$(LOGS_FILE) 2>&1
# 	@kubectl apply -f release/aux/product-redis.yaml >> $(LOGS_FILE) 2>&1
	@kubectl apply -f release/aux/cart-redis.yaml --request-timeout=2m >> $(LOGS_FILE) 2>&1
	@sleep 5

	@echo creating OB ... >> $(LOGS_FILE)
	@kubectl apply -f $(WEAVER_GEN_YAML) >> $(LOGS_FILE) 2>&1
	sleep 10

	@echo creating loadgenerator... >> $(LOGS_FILE)
	@kubectl apply -f $(LOAD_GEN_YAML) >> $(LOGS_FILE) 2>&1

# 	@if [ "$(TRACE_ENABLE)" = "true" ]; then \
# 		echo "Jaeger is enabled, starting to collect trace" ; \
# 	    kubectl apply -f $(JAEGER_TRACE_YAML) >> $(DEBUG_OUTPUT) 2>&1; \
# 	else \
# 	    echo "Skipping Jaeger deployment." >> $(DEBUG_OUTPUT); \
# 	fi

	@if [ "$(METRIC_ENABLE)" = "true" ]; then \
		echo "prometheus is enabled, starting to collect metrics" ; \
	    kubectl apply -f $(PROMETHEUS_METRIC_YAML) >> $(DEBUG_OUTPUT) 2>&1; \
	else \
	    echo "Skipping prometheus deployment." >> $(DEBUG_OUTPUT); \
	fi

	@# If we need to pin, we wait a while because it takes a min to start up.
	@if [[ $$BENCH_TYPE = "STATIC" ]]; then sleep 25; ./scripts/pin_pods.sh | tee -a $(LOGS_FILE); fi


# Can be run by user 
# Used to benchmark app under environment specified by env vars
bench: deploy	

	@if [[ $$RUNTIME_METRIC_ENABLE = "true" ]]; then \
		taskset -c 5-25 ./scripts/runtime_metrics_stats.sh;        \
	elif [[ $$BENCH_TYPE = "PERF" ]]; then      \
		./scripts/perf_stats.sh;                  \
	elif [[ $$TRACE_ENABLE = "true" ]]; then    \
		./scripts/traces_stats.sh;                 \
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
	kubectl delete -f $(LOAD_GEN_YAML)
	kubectl delete -f $(WEAVER_GEN_YAML)
	kubectl delete -f release/base/redis.yaml
	# @-kubectl delete all --all >> $(DEBUG_OUTPUT) 2>&1

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

$(KUBE_BIN): $(KUBE_SRC) $(WEAVER)
	go build -C weaver-kube/cmd/weaver-kube
	cp ./weaver-kube/cmd/weaver-kube/weaver-kube $(WEAVER_BIN_PATH)

$(TRACE_BIN): weaver-kube/examples/telemetry-traces/main.go $(KUBE_SRC) $(WEAVER)
	(cd weaver-kube/examples/telemetry-traces && go build -o telemetry-traces .)
	cp ./weaver-kube/examples/telemetry-traces/telemetry-traces $(WEAVER_BIN_PATH)

# $(METRIC_BIN): weaver-kube/examples/telemetry-metrics/main.go $(KUBE_SRC) $(WEAVER)
# 	(cd weaver-kube/examples/telemetry-metrics && go build -o telemetry-metrics .)
# 	cp ./weaver-kube/examples/telemetry-metrics/telemetry-metrics $(WEAVER_BIN_PATH)

#rebuild the binary if weaver kube src was modified
bin_build: $(KUBE_BIN) $(TRACE_BIN) $(METRIC_BIN)
# bin_build: $(KUBE_BIN)

# if deployment specifications or src code was modified,
# 	Update Weaver kubernetes yaml
# 	modifies version file, which should trigger LOAD_GEN_YAML
$(WEAVER_GEN_YAML): $(KUBE_BASE_YAML) $(BIN) $(CONFIG_FILE) .env
	@echo rebuilding onlineboutique container...
	
	@if [ $$BENCH_TYPE != "STATIC" ]; then \
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

# If src code or .env (since checkout functionality var is defined there) were modified,
#	Update binary
$(BIN): $(MAIN_SRC) .env Makefile $(WEAVER_SRC)
	@echo rebuilding binary...
	
	@cd $(SRC); ../$(WEAVER) generate -tags $(CHECKOUT_FUNCTIONALITY) ./...; go build -tags $(CHECKOUT_FUNCTIONALITY) -o ../release/generated; cd ..
	@mv release/generated/Weaver-OB-Bench release/generated/ob


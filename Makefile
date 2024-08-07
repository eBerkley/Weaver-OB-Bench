.EXPORT_ALL_VARIABLES:

DOCKER := docker.io/eberkley

TOP := .

RELEASE := $(TOP)/release
SRC := $(TOP)/src
BENCH := $(TOP)/benchmark

BASE := $(RELEASE)/base
GENERATED := $(RELEASE)/generated

IMGS := $(BENCH)/imgs
STATS := $(BENCH)/stats

KUBE_BASE_YAML := $(BASE)/kube.yaml
LOAD_BASE_YAML := $(BASE)/loadgen.yaml

KUBE_GEN_YAML := $(GENERATED)/kube.yaml
WEAVER_GEN_YAML := $(GENERATED)/gen.yaml
LOAD_GEN_YAML := $(GENERATED)/loadgen.yaml

COLOCATION_FNAMES := $(wildcard $(BASE)/colocation/*.yaml)
COLOCATION_BASE := $(foreach var, $(COLOCATION_FNAMES), $(shell basename $(var) .yaml))


BIN := $(GENERATED)/onlineboutique

LOAD_SRC := $(SRC)/loadgenerator
LOAD_SRC_ALL := $(LOAD_SRC)/entrypoint.sh $(LOAD_SRC)/locustfile.py

# All .go files in src/** that aren't generated
MAIN_SRC := $(filter-out %weaver_gen.go, $(wildcard $(SRC)/*/*.go))

VERSION_FILE := $(GENERATED)/version.txt

.PHONY: all clean minikube_start minikube_restart check_smt toggle_smt deploy bench bench_all plot plot_quick stop 

all:
	@echo valid arguments:
	@echo
	@echo	"minikube_[re]start   - [re]start minikube"
	@echo "check_smt            - View if hyperthreading is enabled"
	@echo "toggle_smt           - Toggle hyperthreading. NOTE: May require root."
	@echo "deploy               - Starts minikube / builds new version of app if necessary, then deploys."
	@echo "bench                - Functionally equivilent to benchmark/benchmark.sh"
	@echo "bench_all            - Run benchmark using every colocation scheme in release/base/colocation"
	@echo "plot                 - For when 'bench' has finished running"
	@echo "stop                 - remove deployments"

minikube_start:
	@ lines=$(shell minikube status | wc -l);	\
	if [ $$lines -le 5 ]; then 								\
		echo Starting minikube;									\
		./scripts/minikube_start.sh;						\
	else 																			\
		echo Minikube already running. ;				\
	fi 

minikube_restart:
	minikube delete
	./scripts/minikube_start.sh

check_smt:
	./scripts/hyperthreading.sh

toggle_smt:
	./scripts/hyperthreading.sh 2

deploy: minikube_start $(WEAVER_GEN_YAML) $(LOAD_GEN_YAML)
	-./scripts/stop.sh
	kubectl apply -f $(WEAVER_GEN_YAML)
	kubectl apply -f $(LOAD_GEN_YAML)

bench: deploy
	./scripts/pull_stats.sh
	./scripts/stop.sh

bench_all: minikube_start $(WEAVER_GEN_YAML) $(LOAD_GEN_YAML)
	@echo Colocation Schemes: $(COLOCATION_BASE)
	@echo 
	./bench_all.sh

plot:
	@for var in $(COLOCATION_BASE); do		\
		echo $$var;													\
		./benchmark/bar.py $$var;						\
		./benchmark/make_csv.py $$var;			\
		./benchmark/plot_compare.py $$var;	\
	done;

stop:
	./scripts/stop.sh
	minikube delete

# if deployment specifications or src code was modified,
# 	Update Weaver kubernetes yaml
# 	modifies version file, will trigger LOAD_GEN_YAML
$(WEAVER_GEN_YAML): $(KUBE_GEN_YAML) $(BIN)
	
	./make_scripts/weaver_gen_yaml.sh 

# if Loadgen code was modified,
#	Update Load Generator
$(LOAD_GEN_YAML): $(LOAD_SRC_ALL) $(VERSION_FILE)
	./make_scripts/load_gen_yaml.sh

# If src code was modified, 
#	Update binary
$(BIN): $(MAIN_SRC)
	weaver generate src/...
	cd $(SRC); go build -o ../release/generated; cd ..
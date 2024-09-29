.EXPORT_ALL_VARIABLES:

TOP := .

WEAVER_DIR := $(TOP)/weaver
WEAVER_CMD := $(WEAVER_DIR)/cmd/weaver
WEAVER := $(WEAVER_CMD)/weaver

RELEASE := $(TOP)/release
SRC := $(TOP)/src
BENCH := $(TOP)/benchmark

BASE := $(RELEASE)/base
GENERATED := $(RELEASE)/generated

IMGS := $(BENCH)/imgs
STATS := $(BENCH)/stats

WEAVER_BASE_TOML := $(BASE)/weaver.toml
WEAVER_GEN_TOML := $(GENERATED)/weaver.toml


SCHEME_DIR := $(BASE)/colocation
COLOCATION_FNAMES := $(wildcard $(SCHEME_DIR)/*.toml)
COLOCATION_BASE := $(foreach var, $(COLOCATION_FNAMES), $(shell basename $(var) .yaml))


BIN := $(GENERATED)/ob

LOAD_SRC := $(SRC)/loadgenerator
LOAD_SRC_ALL := $(LOAD_SRC)/entrypoint.sh $(LOAD_SRC)/locustfile.py

# All .go files in src/** that aren't generated
MAIN_SRC := $(filter-out %weaver_gen.go, $(wildcard $(SRC)/*/*.go))

LOGS_FILE := $(TOP)/logs.txt

.PHONY: all clean check_smt toggle_smt deploy bench bench_all plot plot_quick stop clear_logs

all:
	@echo valid arguments:
	@echo
	@echo "check_smt            - View if hyperthreading is enabled"
	@echo "toggle_smt           - Toggle hyperthreading. NOTE: May require root."
	@echo "bench                - Functionally equivilent to benchmark/benchmark.sh"
	@echo "bench_all            - Run benchmark using every colocation scheme in release/base/colocation"
	@echo "plot                 - For when 'bench' has finished running"
	@echo "stop                 - remove deployments"

deploy: $(WEAVER) $(BIN)
	$(WEAVER) multi deploy $(WEAVER_GEN_TOML)
	# weaver multi deploy $(WEAVER_GEN_TOML)

check_smt:
	./scripts/hyperthreading.sh

toggle_smt:
	./scripts/hyperthreading.sh 2
	
stop:
	$(WEAVER) multi purge --force

bench: deploy
	./scripts/pull_stats.sh 
	@echo deleting deployment...
	./scripts/stop.sh >/dev/null

$(WEAVER):
	cd $(WEAVER_CMD); go build .



# ./bench_all changes $(WEAVER_GEN_YAML) every time it runs, 
# 	new images built each time.
bench_all: clear_logs 
	@echo Colocation Schemes: $(COLOCATION_BASE)
	@echo 
	./make_scripts/bench_all.sh

plot:
	@for var in $(COLOCATION_BASE); do\
		echo $$var;\
		./benchmark/bar.py $$var;\
		./benchmark/make_csv.py $$var;\
		./benchmark/plot_compare.py $$var;\
	done

# If src code was modified, 
#	Update binary
$(BIN): $(MAIN_SRC)
	@echo rebuilding binary...

	@cd $(SRC); $(WEAVER) generate ./...; go build -o ../release/generated; cd ..
	@mv release/generated/onlineboutique release/generated/ob

clear_logs: $(LOGS_FILE)
	@echo clearing logs...

	@printf "" > $(LOGS_FILE)

$(LOGS_FILE):
	@echo creating $(LOGS_FILE)...
	@touch $(LOGS_FILE)
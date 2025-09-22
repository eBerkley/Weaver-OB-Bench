SHELL ?= /bin/bash


export_allocations:
	@./scripts/export_allocations.sh


check_docker: 
	@./make_scripts/check_docker.sh

# minikube_start:
# 	@ lines=$(shell minikube status | wc -l);\
# 	if [ $$lines -le 5 ]; then\
# 		echo Starting minikube;\
# 		./scripts/minikube_start.sh;\
# 		if [[ $$BENCH_TYPE = "STATIC" ]]; then \
# 			echo Using static bench config.; \
# 			./scripts/pin_system.sh; \
# 		fi \
# 	else \
# 		echo Minikube already running. ;\
# 	fi 

k3s_start:
	@sudo k3s server --kubelet-arg=config=$$PWD/release/aux/kubelet.conf --disable traefik

graph:
	python3 benchmark/analyze.py -m graph_many -n "$$NAME" -g "$$TYPE"

analyze:
	@if [ -z "$(S)" ]; then                                                    \
		echo "Error: Need to define scheme name. ex: 'make S=MCu analyze'" >&2 ; \
		exit 1;                                                                  \
	else                                                                       \
		python3 ./benchmark/analyze.py -m term -n $(S);                          \
	fi

results:
	@if [ -z "$(S)" ]; then                                                      \
		echo "Error: Need to define scheme name. ex: 'make S=MCu results'" >&2 ;   \
		exit 1;                                                                    \
	else                                                                         \
		python3 ./benchmark/analyze.py -m csv -n $(S) >benchmark/results/$(S).csv; \
	fi

results_all:
	@for a in $(shell ls benchmark/out); do                                     \
		if ! grep "BENCH_TYPE=ALLOC" benchmark/out/$$a/info.txt &>/dev/null; then \
			echo $$a;                                                               \
			make S=$$a results >/dev/null;                                          \
		fi;                                                                       \
	done

results_new:
	@for a in $(shell ls benchmark/out); do                                     \
		if ! grep "BENCH_TYPE=ALLOC" benchmark/out/$$a/info.txt &>/dev/null; then \
	 		if [[ ! -e benchmark/results/$$a.csv ]]; then                           \
	 	  	echo $$a;                                                             \
	 			make S=$$a results >/dev/null;                                        \
	 		fi;                                                                     \
	 	fi;                                                                       \
	 done

results_new_dry:
	@for a in $(shell ls benchmark/out); do                                     \
		if ! grep "BENCH_TYPE=ALLOC" benchmark/out/$$a/info.txt &>/dev/null; then \
	 		if [[ ! -e benchmark/results/$$a.csv ]]; then                           \
	 	  	echo $$a;                                                             \
	 		fi;                                                                     \
	 	fi;                                                                       \
	 done


# Will try to ignore errors i.e. if minikube wasn't running
minikube_restart:
	- minikube delete
	./scripts/minikube_start.sh

check_smt:
	./scripts/hyperthreading.sh

toggle_smt:
	./scripts/hyperthreading.sh 2


stop:
	./scripts/stop.sh
	minikube delete

LOGS_FILE ?= ./logs.txt

clear_logs: $(LOGS_FILE)
	@echo clearing logs...
	@printf "" > $(LOGS_FILE)

$(LOGS_FILE):
	@echo creating $(LOGS_FILE)...
	@touch $(LOGS_FILE)

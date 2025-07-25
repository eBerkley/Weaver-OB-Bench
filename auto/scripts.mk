SHELL ?= /bin/bash


export_allocations:
	@./scripts/export_allocations.sh


check_docker: 
	@./make_scripts/check_docker.sh

minikube_start:
	@ lines=$(shell minikube status | wc -l);\
	if [ $$lines -le 5 ]; then\
		echo Starting minikube;\
		./scripts/minikube_start.sh;\
		if [[ $$BENCH_TYPE = "STATIC" ]]; then \
			echo Using static bench config.; \
			./scripts/pin_system.sh; \
		fi \
	else \
		echo Minikube already running. ;\
	fi 

graph:
	python3 benchmark/analyze.py -m graph_many -n "$$NAME" -g "$$TYPE"

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

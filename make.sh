#!/bin/bash

# Wrapper for make, useful for running without the usual benchmark workflow. 
# Uses DEFAULT.cfg instead of CONFIG.cfg

make CONFIG_FILE=DEFAULT.cfg $*
#!/bin/sh

LOCUST_MODE=${LOCUST_MODE:-standalone}
LOCUST_MASTER_PORT=${LOCUST_MASTER_PORT:-5557}
LOCUST_FILE=${LOCUST_FILE:-locustfile.py}

LOCUST_OPTS="-f ${LOCUST_FILE} $LOCUST_OPTS"
# LOCUST_OPS="--host=${FRONTEND_ADDR} $LOCUST_OPTS"


case `echo ${LOCUST_MODE} | tr 'a-z' 'A-Z'` in
"MASTER")
    # UI mode:
    # LOCUST_OPTS="--master --master-bind-port=${LOCUST_MASTER_PORT} $LOCUST_OPTS"

    # Benchmarking mode:
    LOCUST_OPTS="--master --master-bind-port=${LOCUST_MASTER_PORT} $LOCUST_OPTS --headless --host="http://${FRONTEND_ADDR}" --only-summary --csv /stats/lat --csv-full-history"
    
    
    ;;

"WORKER")
    LOCUST_OPTS="--worker --master-host=${LOCUST_MASTER} --master-port=${LOCUST_MASTER_PORT} $LOCUST_OPTS"
    if [ -z ${LOCUST_MASTER+x} ] ; then
        echo "You need to set LOCUST_MASTER."
        exit 1
    fi
    ;;

esac


locust ${LOCUST_OPTS}
echo all done!
sleep 30

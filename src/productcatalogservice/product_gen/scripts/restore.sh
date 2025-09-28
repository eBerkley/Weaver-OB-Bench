#!/bin/bash

conn_str='mongodb+srv://root:productDB@mongo-mongodb-sharded.default.svc.cluster.local/?tls=false&authSource=admin&readPreference=nearest'

mongosh $conn_str --file init.js

while [[ ! -e 'doorbell.txt' ]]; do
  sleep 1
done


mongorestore --uri="$conn_str" ./dump

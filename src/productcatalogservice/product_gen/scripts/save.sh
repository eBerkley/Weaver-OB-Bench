#!/bin/bash

conn_str='mongodb+srv://root:productDB@mongo-mongodb-sharded.default.svc.cluster.local/?tls=false&authSource=admin&readPreference=nearest'



mongodump $conn_str -d=product-db


echo 'done' >sendDoorbell.txt

while [[ ! -e 'recvDoorbell.txt' ]]; do 
  sleep 1
done


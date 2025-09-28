#!/bin/bash

set -e

conn_str='mongodb+srv://root:productDB@mongo-mongodb-sharded.default.svc.cluster.local/?tls=false&authSource=admin'

# mongosh $conn_str --file init.js
echo "load(\"init.js\")" >run.js

# There's something like 2k files, heach of which are about 250KB.
# This *will* take a while, better go make a coffee or something while it's running.
# I'm sure there's a better way to do all of this...
for f in products/*.js; do
  echo "load(\"$f\")" >> run.js
done
mongosh $conn_str --file run.js



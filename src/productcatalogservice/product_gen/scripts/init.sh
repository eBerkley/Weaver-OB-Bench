#!/bin/bash

set -e

conn_str='mongodb+srv://root:productDB@mongo-mongodb-sharded.default.svc.cluster.local/?tls=false&authSource=admin'

# mongosh $conn_str --file init.js
echo "load(\"init.js\")" >run.js

echo 'db = db.getSiblingDB("product-db");' >run2.js

# There's something like 2k files, heach of which are about 250KB.
# This *will* take a while, better go make a coffee or something while it's running.
# I'm sure there's a better way to do all of this...
for f in products/*.js; do
  if echo $f | grep -E products/1[0-9]{3} >/dev/null; then
    echo "load(\"$f\")" >> run2.js
  else
    echo "load(\"$f\")" >> run.js
  fi
done

echo "beginning run.js"
mongosh $conn_str --file run.js

echo "beginning run2.js"
mongosh $conn_str --file run2.js
echo "Done!"

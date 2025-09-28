db = db.getSiblingDB("product-db");

// just in case
db.products.drop(); 

// Tell it to shard the collection we use as a database, 
//    using "id" as the shard key.
sh.shardCollection("product-db.products", {"id": "hashed"});

db.products.createIndex( { "name": "text", "category": 1 })
db.products.createIndex( { "category": 1 })

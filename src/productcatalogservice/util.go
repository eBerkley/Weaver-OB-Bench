package productcatalogservice

import (
	"hash/fnv"
)

func redisProductKey(productID string) string {
	return productID + "-pr"
}

func redisSearchKey(query string) string {
	return query + "-kw" // like "keyword"
}

// Gets which index contains the product.
// Might end up using for caching, If I don't I'll delete
func HashProductID(id string, replicas int) int {
	h := fnv.New32a()
	h.Write([]byte(id))
	idx := h.Sum32() % uint32(replicas)
	return int(idx)
}

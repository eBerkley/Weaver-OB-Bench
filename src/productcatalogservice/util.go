package productcatalogservice

import (
	"fmt"
	"hash/fnv"
)

func redisProductKey(productID string) string {
	return fmt.Sprintf("%s-pr", productID)
	// return productID + "-pr"
}

func redisSearchKey(query string, category string) string {
	return fmt.Sprintf("%s-%s-kw", query, category) // like "keyword"
}

// Gets which index contains the product.
// Might end up using for caching, If I don't I'll delete
func HashProductID(id string, replicas int) int {
	h := fnv.New32a()
	h.Write([]byte(id))
	idx := h.Sum32() % uint32(replicas)
	return int(idx)
}

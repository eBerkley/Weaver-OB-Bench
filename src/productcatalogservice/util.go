package productcatalogservice

import (
	"context"
	"fmt"
	"hash/fnv"
	"os"
	"strconv"

	"github.com/eberkley/weaver"
)

// This file is for code that may be used by services besides ProductCatalogService.

var (
	// All pods have this env variable available.
	ProductCatalogReplicas int
)

func init() {
	var err error
	envVal := os.Getenv("weaver_ProductCatalogService_replicas")
	ProductCatalogReplicas, err = strconv.Atoi(envVal)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: env var for number of replicas for ProductCatalogService is of value %v. Trying to parse this value yielded error %v. Using default value of 1.", envVal, err.Error())

		ProductCatalogReplicas = 1
	}
}

// Gets which index contains the product.
func HashProductID(id string) int {
	h := fnv.New32a()
	h.Write([]byte(id))
	idx := h.Sum32() % uint32(ProductCatalogReplicas)
	return int(idx)
}

type ProductRoutingTable map[int]int

func GetRoutingTable(ref weaver.Ref[ProductCatalogService]) ProductRoutingTable {
	// To avoid making MAX_INT=9223372036854775807 RPCs in the event of a
	// routing / deployment error, we lower the max number of values
	// to try before giving up.
	const SEARCH_SPACE int = 10_000
	const NOT_FOUND = -1
	ctx := context.TODO()

	// map[index]routeKey
	routingTable := make(map[int]int, ProductCatalogReplicas)
	for i := 0; i < ProductCatalogReplicas; i++ {
		routingTable[i] = NOT_FOUND
	}

	foundVals := 0
	for key := 0; key < SEARCH_SPACE; key++ {
		idx, _ := ref.Get().GetIndex(ctx, key)
		if routingTable[idx] == NOT_FOUND {
			routingTable[idx] = key
			foundVals++
		}

		if foundVals == ProductCatalogReplicas {
			break
		}
	}

	for i := 0; i < ProductCatalogReplicas; i++ {
		if routingTable[i] == NOT_FOUND {
			return nil
		}
	}

	return routingTable
}

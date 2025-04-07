package productcatalogservice

import (
	"context"
	"fmt"
	"hash/fnv"
	"os"
	"strconv"
	"time"

	"github.com/eberkley/weaver"
)

// This file is for code that may be used by services besides ProductCatalogService.

var (
	// All pods have this env variable available.
	// This may be correct initially, but do NOT assume it always will be.
	ProductCatalogReplicas int
)

const (
	getIndexDelay = time.Duration(25) * time.Millisecond
)

func init() {
	var err error
	envVal := os.Getenv("weaver_ProductCatalogService_replicas")
	ProductCatalogReplicas, err = strconv.Atoi(envVal)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warning: env var for number of replicas for ProductCatalogService is of value %v. Trying to parse this value yielded error %v. Using default value of 2.", envVal, err.Error())

		ProductCatalogReplicas = 2
	}
}

// Gets which index contains the product.
func HashProductID(id string, replicas int) int {
	h := fnv.New32a()
	h.Write([]byte(id))
	idx := h.Sum32() % uint32(replicas)
	return int(idx)
}

type ProductRoutingTable map[int]int

func GetRoutingTable(ctx context.Context, ref *weaver.Ref[ProductCatalogService], replicas int) (ProductRoutingTable, error) {
	// To avoid making MAX_INT=9223372036854775807 RPCs in the event of a
	// routing / deployment error, we lower the max number of values
	// to try before giving up.

	if replicas == -1 {
		replicas = ProductCatalogReplicas
	}

	const SEARCH_SPACE int = 10_000
	const NOT_FOUND int = -1

	// map[index]routeKey
	routingTable := make(map[int]int, replicas)
	for i := 0; i < replicas; i++ {
		routingTable[i] = NOT_FOUND
	}

	foundVals := 0
	for key := 0; key < SEARCH_SPACE; key++ {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()

		default:
			idx, err := ref.Get().GetIndex(ctx, key)
			if err != nil {
				// we just restart whenever one isn't ready.
				for i := 0; i < replicas; i++ {
					routingTable[i] = NOT_FOUND
				}
				foundVals = 0
				continue
			}
			if routingTable[idx] == NOT_FOUND {
				foundVals++
			}
			routingTable[idx] = key

			if foundVals == replicas {
				break
			}
			time.Sleep(getIndexDelay)
		}
	}

	for i := 1; i < replicas+1; i++ {
		if routingTable[i] == NOT_FOUND {
			return nil, fmt.Errorf("invalid routing table: %v", routingTable)
		}
	}

	return routingTable, nil
}

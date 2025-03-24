// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package recommendationservice

import (
	"context"
	"fmt"
	"strings"
	"sync"

	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice"
	"github.com/eberkley/weaver"
	_ "go.uber.org/automaxprocs"
)

type RecService interface {
	ListRecommendations(ctx context.Context, userID string, productIDs []string) ([]string, error)
}

type impl struct {
	weaver.Implements[RecService]
	catalogService weaver.Ref[productcatalogservice.ProductCatalogService]

	catalogRoutingTable productcatalogservice.ProductRoutingTable
}

func (s *impl) Init(ctx context.Context) error {
	s.Logger(ctx).Info("in rec init")
	s.catalogRoutingTable = productcatalogservice.GetRoutingTable(&s.catalogService)
	s.Logger(ctx).Info("out of rec init!!")
	s.Logger(ctx).Info(fmt.Sprintf("routing table: %v", s.catalogRoutingTable))
	return nil
}

func (s *impl) ListRecommendations(ctx context.Context, userID string, userProductIDs []string) ([]string, error) {
	// Get the shards for each productID
	productShardMap := make([][]string, productcatalogservice.ProductCatalogReplicas)
	for _, pid := range userProductIDs {
		shard := productcatalogservice.HashProductID(pid)
		productShardMap[shard] = append(productShardMap[shard], pid)
	}

	// shard index => list of products
	productShards := make([][]productcatalogservice.Product, productcatalogservice.ProductCatalogReplicas)

	// Concurrently send an RPC to each product catalog service. Wait until there's a response from all of them.
	// If one returns an error, this function returns an error.
	wg := sync.WaitGroup{}
	wg.Add(productcatalogservice.ProductCatalogReplicas)
	errChan := make(chan error, productcatalogservice.ProductCatalogReplicas)
	for shard := 0; shard < productcatalogservice.ProductCatalogReplicas; shard++ {
		go func(shard int) {
			// Don't send RPC if we aren't requesting any products.
			if len(productShardMap[shard]) == 0 {
				wg.Done()
				return
			}
			// Routing key that will route to the correct shard.
			key := s.catalogRoutingTable[shard]
			prods, err := s.catalogService.Get().GetProducts(ctx, productShardMap[shard], key)
			if err != nil {
				errChan <- err
			} else {
				productShards[shard] = prods
			}
			wg.Done()

		}(shard)
	}
	// Halt thread until all requests have responses.
	// If theres an error from one, return it. If not, continue on.
	wg.Wait()
	select {
	case err := <-errChan:
		return nil, err
	default:
		break
	}

	// Each product name is 3 words: color, material, object.
	// We split them up into words, give material 2x as much
	freq := make(map[string]int)

	for _, s := range productShards {
		for _, product := range s {
			words := strings.Split(product.Name, " ")
			if len(words) != 3 {
				return nil, fmt.Errorf("product with name %v couldn't be parsed", product.Name)
			}
			freq[words[0]]++
			freq[words[1]]++
			freq[words[2]] += 2
		}
	}
	var searchQuery string
	highestFreq := 0
	for k, v := range freq {
		if v > highestFreq {
			searchQuery = k
		}
	}
	// shard index => list of similar products
	productStringShards := make([][]string, productcatalogservice.ProductCatalogReplicas)

	// Concurrently send another RPC to each product catalog service. Wait until there's a response from all of them.
	// If one returns an error, this function returns an error.
	wg.Add(productcatalogservice.ProductCatalogReplicas)
	errChan2 := make(chan error, productcatalogservice.ProductCatalogReplicas)
	for shard := 0; shard < productcatalogservice.ProductCatalogReplicas; shard++ {
		go func(shard int) {
			// Routing key that will route to the correct shard.
			key := s.catalogRoutingTable[shard]
			// Get all similar products
			prods, err := s.catalogService.Get().SearchProducts(ctx, searchQuery, key)
			if err != nil {
				errChan2 <- err
				wg.Done()
				return
			}
			// remove ones in userProductIDs paramater.
			// Since only the products in this shard could be returned by
			// this method call, we just use the products in productShards[shard].
			for _, prod := range prods {
				for _, userProd := range productShards[shard] {
					if prod.ID == userProd.ID {
						break
					}
				}
				productStringShards[shard] = append(productStringShards[shard], prod.ID)
			}
			wg.Done()
		}(shard)
	}

	// Halt thread until all requests have responses.
	// If theres an error from one, return it. If not, continue on.
	wg.Wait()
	select {
	case err := <-errChan2:
		return nil, err
	default:
		break
	}

	// Get the aggregate of products.
	var ret []string
	for _, s := range productStringShards {
		ret = append(ret, s...)
	}

	return ret, nil
}

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
	"time"

	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice"
	"github.com/eberkley/weaver"
	"github.com/eberkley/weaver/runtime"
	imetrics "github.com/eberkley/weaver/runtime/codegen"
	_ "go.uber.org/automaxprocs"
)

type RecService interface {
	ListRecommendations(ctx context.Context, userID string, productIDs []string) ([]string, error)
}

type impl struct {
	weaver.Implements[RecService]
	catalogService weaver.Ref[productcatalogservice.ProductCatalogService]

	catalogMu       sync.RWMutex
	catalogInit     bool
	catalogReplicas int
	cancelFn        context.CancelFunc
}

func (s *impl) Init(ctx context.Context) error {

	if s.catalogReplicas == 0 {
		s.catalogReplicas = productcatalogservice.ProductCatalogReplicas
	}
	s.Logger(ctx).Info("in Init function")
	// s.UpdateCatalogService(ctx, s.catalogReplicas)

	return nil
}

func (s *impl) UpdateCatalogService(ctx2 context.Context, replicas int) {
	ctx, cancelFn := context.WithCancel(ctx2)

	if s.cancelFn != nil {
		s.cancelFn()
	}

	s.cancelFn = cancelFn
	s.Logger(ctx).Debug("running UpdateCatalogService", "replicas", replicas)

	updateCatalogInfo := func() {
		s.Logger(ctx).Debug("UpdateCatalogService: in updateCatalogInfo", "replicas", replicas)

		s.catalogMu.Lock()
		s.catalogReplicas = replicas
		s.catalogMu.Unlock()
	}

	if !s.catalogInit {
		s.Logger(ctx).Debug("UpdateCatalogService: s.catalogInit == false, not waiting", "replicas", replicas)
		updateCatalogInfo()
		s.catalogInit = true
		return
	}

	timer := time.NewTimer(time.Duration(5) * time.Second)
	go func() {
		select {
		case <-timer.C:
			updateCatalogInfo()
			s.Logger(context.TODO()).Debug("UpdateCatalogService: updateCatalogInfo returning. ", "replicas'", replicas)

		case <-ctx.Done():
			s.Logger(context.TODO()).Debug("UpdateCatalogService: context cancelled", "replicas", replicas)
		}

	}()

}

func (s *impl) UpdateRoutingHook(ctx context.Context, componentName string, replicas int) error {
	s.Logger(ctx).Info("in UpdateRoutingHook", "componentName", componentName, "replicas", replicas)

	if !strings.HasSuffix(componentName, "ProductCatalogService") {
		if strings.HasSuffix(componentName, "RecService") {
			return runtime.RoutingDontCareError
		}
		return nil
	}

	if replicas == -1 {
		return nil
	}

	s.UpdateCatalogService(ctx, replicas)
	return nil
}

func (s *impl) ListRecommendations(ctx context.Context, userID string, userProductIDs []string) ([]string, error) {
	initTime := time.Now()
	var duration time.Duration

	defer func() {
		totalDuration := time.Since(initTime) - duration
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService", Method: "ListRecommendations"}).Put(float64(totalDuration.Microseconds()))
	}()

	// Get the shards for each productID

	// A call to ListRecommendations will use the same routing info for the full run
	s.catalogMu.RLock()
	repls := s.catalogReplicas
	s.catalogMu.RUnlock()

	productShardMap := make([][]string, repls)
	for _, pid := range userProductIDs {
		shard := productcatalogservice.HashProductID(pid, repls)
		productShardMap[shard] = append(productShardMap[shard], pid)
	}

	productShards := make([][]productcatalogservice.Product, repls)

	// shard index => list of products

	// Concurrently send an RPC to each product catalog service. Wait until there's a response from all of them.
	// If one returns an error, this function returns an error.
	wg := sync.WaitGroup{}
	wg.Add(repls)
	errChan := make(chan error, repls)

	concurrentGetProductsTime := time.Now()
	for shard := 0; shard < repls; shard++ {
		go func(shard int) {
			// Don't send RPC if we aren't requesting any products.
			if len(productShardMap[shard]) == 0 {
				wg.Done()
				return
			}
			// Routing key that will route to the correct shard.
			prods, err := s.catalogService.Get().GetProducts(ctx, productShardMap[shard], shard)

			if err != nil {
				s.Logger(ctx).Error("ListRecommendations: GetProducts error", "productIDs", userProductIDs, "err", err, "shard", shard)
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
	duration += time.Since(concurrentGetProductsTime)

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
	productStringShards := make([][]string, repls)

	// Concurrently send another RPC to each product catalog service. Wait until there's a response from all of them.
	// If one returns an error, this function returns an error.
	wg.Add(repls)
	errChan2 := make(chan error, repls)
	concurrentSearchProductsTime := time.Now()
	for shard := 0; shard < repls; shard++ {
		go func(shard int) {
			// Get all similar products
			prods, err := s.catalogService.Get().SearchProducts(ctx, searchQuery, shard)

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
	duration += time.Since(concurrentSearchProductsTime)
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

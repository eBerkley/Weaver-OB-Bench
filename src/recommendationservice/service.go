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
	ListRecommendations(ctx context.Context, productIDs []string) ([]string, error)
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

	s.Logger(ctx).Info("in Init function")

	// go func() {
	// 	ticker := time.NewTicker(time.Second)
	// 	defer ticker.Stop()
	// 	for {
	// 		select {
	// 		case <-ctx.Done():
	// 			return
	// 		case <-ticker.C:
	// 			imetrics.GroupGoroutineFor(imetrics.ComponentLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService"}).Set(float64(goruntime.NumGoroutine()))
	// 		}
	// 	}
	// }()

	return nil
}

func (s *impl) ListRecommendations(ctx context.Context, userProductIDs []string) ([]string, error) {
	// initTime := time.Now()
	// var duration time.Duration

	// defer func() {
	// 	totalDuration := time.Since(initTime) - duration
	// 	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService", Method: "ListRecommendations"}).Put(float64(totalDuration.Microseconds()))
	// }()
	if len(userProductIDs) == 0 {
		return []string{}, nil
	}
	products, err := s.catalogService.Get().GetProducts(ctx, userProductIDs)
	if err != nil {
		s.Logger(ctx).Error("ListRecommendations: GetProducts", "err", err, "products", userProductIDs)
		return nil, fmt.Errorf("GetProducts: %w", err)
	}

	// Each product name is 3 words: color, material, object.
	// We split them up into words, give object 2x as much
	freq := make(map[string]int)

	for _, product := range products {
		words := strings.Split(product.Name, " ")
		if len(words) != 3 {
			return nil, fmt.Errorf("product with name %v couldn't be parsed", product.Name)
		}
		freq[words[0]]++
		freq[words[1]]++
		freq[words[2]] += 2
	}

	var searchQuery string
	highestFreq := 0
	for k, v := range freq {
		if v > highestFreq {
			searchQuery = k
			highestFreq = v
		}
	}

	found, err := s.catalogService.Get().SearchProducts(ctx, searchQuery)
	if err != nil {
		s.Logger(ctx).Error("ListRecommendations: SearchProducts", "err", err, "query", searchQuery)
		return nil, fmt.Errorf("SearchProducts: %w", err)
	}
	ret := make([]string, 0)
	for _, prod := range found {
		skip := false
		for _, userProd := range userProductIDs {

			if userProd == prod.ID {
				skip = true
				break
			}
		}

		if !skip {
			ret = append(ret, prod.ID)
		}
	}
	return ret, nil

}

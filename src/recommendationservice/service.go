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

// Invoked on view cart, view product, checkout.
/*
INDEX_FREQ      = 20
CURRENCY_FREQ   = 10
BROWSE_FREQ     = 20
VIEW_CART_FREQ  = 20
ADD_CART_FREQ   = 30
EMPTY_CART_FREQ = 10
CHECKOUT_FREQ   = 10

Total: 120

Add cart: 30 / 120 = 25%
View cart | checkout = 30 = 25%

Its as likely for a user to have an empty cart as a non-empty cart?

Proposed:

INDEX_FREQ      = 30
CURRENCY_FREQ   = 10
BROWSE_FREQ     = 30
VIEW_CART_FREQ  = 10
ADD_CART_FREQ   = 25
EMPTY_CART_FREQ = 5
CHECKOUT_FREQ   = 10

total: 120

*/
func (s *impl) ListRecommendations(ctx context.Context, userProductIDs []string) ([]string, error) {
	// initTime := time.Now()
	// var duration time.Duration

	// defer func() {
	// 	totalDuration := time.Since(initTime) - duration
	// 	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/recommendationservice/RecService", Method: "ListRecommendations"}).Put(float64(totalDuration.Microseconds()))
	// }()
	if len(userProductIDs) == 0 {
		s.Logger(ctx).Info("len(productIds) = 0...")
		return []string{}, nil
	}
	// s.Logger(ctx).Info("normal", "len", len(userProductIDs))

	products, err := s.catalogService.Get().GetProducts(ctx, userProductIDs)
	if err != nil {
		s.Logger(ctx).Error("ListRecommendations: GetProducts", "err", err, "products", userProductIDs)
		return nil, fmt.Errorf("GetProducts: %w", err)
	}

	// Each product name is 3 words: color, material, object.
	// Each product category is 1-2 of accessories, clothing, tops, footwear,	hair,	beauty,	decor, home, kitchen.
	// We get the frequencies of each (cat, word) pairing, and additionally a set of each pair.
	// We will only suggest a pair if their is at least one product in the cart that fits.
	catFreq := make(map[string]int)
	wordFreq := make(map[string]int)

	// In cat -> word order
	pairs := make(map[string]map[string]struct{})

	for _, product := range products {
		words := strings.Split(product.Name, " ")
		if len(words) != 3 {
			return nil, fmt.Errorf("product with name %v couldn't be parsed", product.Name)
		}
		wordFreq[words[0]]++
		wordFreq[words[1]]++
		wordFreq[words[2]]++
		for _, cat := range product.Categories {
			if _, ok := pairs[cat]; !ok {
				pairs[cat] = make(map[string]struct{})
			}
			pairs[cat][words[0]] = struct{}{}
			pairs[cat][words[1]] = struct{}{}
			pairs[cat][words[2]] = struct{}{}
			catFreq[cat]++
		}
	}

	// Next, we get the most common of each thing.
	var wQuery string
	var cQuery string
	highestWFreq := 0
	highestCFreq := 0

	for k, v := range wordFreq {

		if v > highestWFreq {
			wQuery = k
			highestWFreq = v
		}
	}

	for k, v := range catFreq {
		if v > highestCFreq {
			cQuery = k
			highestCFreq = v
		}
	}

	if _, ok := pairs[cQuery][wQuery]; ok {

		if highestWFreq > highestCFreq*2 {
			cQuery = ""
		} else if highestCFreq > highestWFreq*2 {
			wQuery = ""
		}

	} else {
		// User never actually wanted a pairing of the two; may not even exist.
		if highestCFreq > highestWFreq {
			wQuery = ""
		} else {
			cQuery = ""
		}
	}

	found, err := s.catalogService.Get().SearchProducts(ctx, wQuery, cQuery)
	if err != nil {
		s.Logger(ctx).Error("ListRecommendations: SearchProducts", "err", err, "word", wQuery, "category", cQuery)
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
	if len(ret) == 0 {
		s.Logger(ctx).Info("Returning empty product array. ", "word", wQuery, "cat", cQuery)
	}
	return ret, nil
}

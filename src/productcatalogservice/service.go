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

package productcatalogservice

import (
	"context"
	"encoding/json"
	"math/rand"
	"path"
	"sync"
	"time"

	"embed"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	"github.com/eberkley/weaver/runtime"
	imetrics "github.com/eberkley/weaver/runtime/codegen"
	_ "go.uber.org/automaxprocs"
)

const (
	maxProducts = 10
)

var (
	//go:embed products/*
	catalogFileData embed.FS
)

type Product struct {
	weaver.AutoMarshal
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Picture     string  `json:"picture"`
	PriceUSD    money.T `json:"priceUsd"`

	// Categories such as "clothing" or "kitchen" that can be used to look up
	// other related products.
	Categories []string `json:"categories"`
}

type ProductCatalogService interface {
	ListProducts(ctx context.Context, routingKey int) ([]Product, error)
	GetProduct(ctx context.Context, productID string, routingKey int) (Product, error)
	GetProducts(ctx context.Context, productIDs []string, routingKey int) ([]Product, error)
	SearchProducts(ctx context.Context, query string, routingKey int) ([]Product, error)
	GetIndex(ctx context.Context, shard int) (int, error)
}

type ProductCatalogRouter struct{}

func (r *ProductCatalogRouter) ListProducts(_ context.Context, shard int) int         { return shard }
func (r *ProductCatalogRouter) GetProduct(_ context.Context, _ string, shard int) int { return shard }
func (r *ProductCatalogRouter) GetProducts(_ context.Context, _ []string, shard int) int {
	return shard
}
func (r *ProductCatalogRouter) SearchProducts(_ context.Context, _ string, shard int) int {
	return shard
}
func (r *ProductCatalogRouter) GetIndex(_ context.Context, shard int) int { return shard }

type impl struct {
	weaver.Implements[ProductCatalogService]
	weaver.WithRouter[ProductCatalogRouter]

	// Doesn't change.
	myIndex int

	mu              sync.RWMutex
	prevCtx         context.Context    // Cancel if we should NOT delete the contents of db when timer expires
	prevCtxCancelFn context.CancelFunc // see impl.prevCtx
	db              map[string]Product
	prevDb          map[string]Product // temporarily stores the previous contents of db
	catalogReplicas int
}

var _ ProductCatalogService = (*impl)(nil)

func (s *impl) Init(ctx context.Context) error {
	var err error
	indexStr := os.Getenv("MY_INDEX")
	s.myIndex, err = strconv.Atoi(indexStr)

	s.db = make(map[string]Product)
	s.prevDb = make(map[string]Product)

	if err != nil {
		s.myIndex = rand.Intn(2)
		s.Logger(ctx).Warn("Envvar MY_INDEX is non-int value. Randomly setting to either 0 or 1:", "value", s.myIndex)
	}
	s.Logger(ctx).Info(fmt.Sprintf("myIndex: %v", s.myIndex))

	// Since we can't do anything until s.db is initialized anyways, we lock the db before calling refreshCatalogFile.
	s.mu.Lock()
	if s.catalogReplicas == 0 {
		s.catalogReplicas = ProductCatalogReplicas
	}
	s.prevCtx, s.prevCtxCancelFn = context.WithCancel(ctx)
	s.db, err = s.refreshCatalogFile(s.prevCtx, s.catalogReplicas)
	s.mu.Unlock()

	if err != nil {
		return fmt.Errorf("could not parse product catalog: %w", err)
	}

	return nil
}

func (s *impl) UpdateRoutingHook(ctx context.Context, componentName string, replicas int) error {

	if !strings.HasSuffix(componentName, "ProductCatalogService") {
		return runtime.RoutingDontCareError
	}
	s.Logger(ctx).Info("running UpdateRoutingHook", "replicas", replicas)
	if replicas == -1 {
		return nil
	}
	// Will halt previous s.refreshCatalogFile() invocation, if one is running.
	// Will prevent prevDb from being cleared, if it hasn't already.
	if s.prevCtxCancelFn != nil {
		s.prevCtxCancelFn()
	}

	// Do we need to lock here?
	s.prevCtx, s.prevCtxCancelFn = context.WithCancel(ctx)

	db, _ := s.refreshCatalogFile(s.prevCtx, replicas)
	if db == nil {
		return nil // Fix later if necessary
	}
	s.Logger(ctx).Info("refreshCatalogFile ran successfully.")

	s.mu.Lock()
	s.catalogReplicas = replicas

	// TODO: verify that this kind of swap is ok
	s.prevDb = s.db
	s.db = db

	s.mu.Unlock()

	t := time.NewTimer(time.Duration(1) * time.Minute)
	go func() {
		prevCtx := s.prevCtx
		select {
		case <-t.C: // If timer expires before a new replica is created, delete old db.
			s.Logger(ctx).Info("Timer expired, deleting old db.")
			// We optimistically assume it's ok to delete stuff
			// out of the old database without locking.
			for k := range s.prevDb {
				delete(s.prevDb, k)
			}

		case <-prevCtx.Done(): // if we reset db, we don't want to prematurely delete old db.
			s.Logger(s.prevCtx).Info("Context cancelled, keeping db!")
			// Do we need to do anything with db or prevDB to store intermediate databases?
			return
		}
	}()

	return nil
}

func (s *impl) fillDB(agg []Product, db map[string]Product, repls int) {

	for _, p := range agg {
		if HashProductID(p.ID, repls) == s.myIndex {
			db[p.ID] = p
		}
	}
}

func (s *impl) refreshCatalogFile(ctx context.Context, repls int) (map[string]Product, error) {

	dir, err := catalogFileData.ReadDir("products")
	if err != nil {
		return nil, err
	}
	db := make(map[string]Product)

	for _, entry := range dir {
		select {
		case <-ctx.Done(): // If a new UpdateRoutingHook is getting fired, stop running this.
			return nil, ctx.Err()
		default:

			data, err := catalogFileData.ReadFile(path.Join("products", entry.Name()))

			if err != nil {
				return nil, err
			}

			var products []Product

			if err := json.Unmarshal(data, &products); err != nil {
				return nil, err
			}

			s.fillDB(products, db, repls)
		}
	}

	return db, nil

}

func (s *impl) ListProducts(ctx context.Context, _ int) ([]Product, error) {
	initTime := time.Now()
	defer func() {
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService", Method: "ListProducts"}).Put(float64(time.Since(initTime).Microseconds()))
	}()

	ls := make([]Product, maxProducts)
	i := 0
	for _, p := range s.db {
		ls[i] = p
		i++
		if i >= maxProducts {
			break
		}
	}
	return ls, nil
}

func (s *impl) GetProduct(ctx context.Context, productID string, _ int) (Product, error) {
	initTime := time.Now()
	defer func() {
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService", Method: "GetProduct"}).Put(float64(time.Since(initTime).Microseconds()))
	}()

	s.mu.RLock()
	defer s.mu.RUnlock()
	var p Product
	var ok bool

	p, ok = s.db[productID]

	// If it wasn't in the original db, try the old one...
	if !ok {
		p, ok = s.prevDb[productID]

		// if we STILL haven't found it...
		if !ok {
			idx := s.myIndex
			needed := HashProductID(productID, s.catalogReplicas)
			return Product{}, fmt.Errorf("request for productID %v made to shard %v, but needed to be %v", productID, idx, needed)
		}
	}

	return p, nil
}

func (s *impl) GetProducts(ctx context.Context, productIDs []string, _ int) ([]Product, error) {
	initTime := time.Now()
	defer func() {
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService", Method: "GetProducts"}).Put(float64(time.Since(initTime).Microseconds()))
	}()

	s.mu.RLock()
	defer s.mu.RUnlock()

	products := make([]Product, len(productIDs))
	for i, pid := range productIDs {

		var p Product
		var ok bool

		p, ok = s.db[pid]

		if !ok {
			p, ok = s.prevDb[pid]

			if !ok {
				idx := s.myIndex
				needed := HashProductID(pid, s.catalogReplicas)
				return nil, fmt.Errorf("request for productID %v made to shard %v, but needed to be %v", pid, idx, needed)
			}
		}

		products[i] = p
	}
	return products, nil
}

func (s *impl) SearchProducts(ctx context.Context, query string, _ int) ([]Product, error) {
	initTime := time.Now()
	defer func() {
		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/productcatalogservice/ProductCatalogService", Method: "SearchProducts"}).Put(float64(time.Since(initTime).Microseconds()))
	}()
	// Interpret query as a substring match in name or description.
	var ps []Product
	i := 0
	q := strings.ToLower(query)

	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, p := range s.db {
		if strings.Contains(strings.ToLower(p.Name), q) {
			ps = append(ps, p)
			i++
			if i >= maxProducts {
				break
			}
		}
	}
	return ps, nil
}

func (s *impl) GetIndex(_ context.Context, _ int) (int, error) { return s.myIndex, nil }

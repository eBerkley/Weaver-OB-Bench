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
	"path/filepath"

	// _ "embed"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	_ "go.uber.org/automaxprocs"
)

const (
	maxProducts = 10
)

// var (
// //go:embed products.json
// catalogFileData []bytes
// )

func must[T any](t T, err error) T {
	if err != nil {
		panic(err)
	}
	return t
}

var productsDirname = filepath.Clean(filepath.Join(filepath.Dir(must(os.Executable())), "..", "products"))

type NotFoundError struct{}

func (e NotFoundError) Error() string { return "product not found" }

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

	// mu      sync.RWMutex
	db      map[string]Product
	myIndex int
}

var _ ProductCatalogService = (*impl)(nil)

func (s *impl) Init(ctx context.Context) error {
	var err error
	indexStr := os.Getenv("MY_INDEX")
	s.myIndex, err = strconv.Atoi(indexStr)
	if err != nil {
		s.Logger(ctx).Warn("Envvar MY_INDEX is non-int value. Assuming default value of 1...", "MY_INDEX", indexStr)
		s.myIndex = 1
	}

	err = s.refreshCatalogFile()
	if err != nil {
		return fmt.Errorf("could not parse product catalog: %w", err)
	}

	return nil
}

func (s *impl) fillDB(agg []Product) {
	for _, p := range agg {
		if HashProductID(p.ID) == s.myIndex {
			s.db[p.ID] = p
		}
	}
}

func (s *impl) refreshCatalogFile() error {

	entries, err := os.ReadDir(productsDirname)
	if err != nil {
		return err
	}
	for _, entry := range entries {

		file, err := os.Open(filepath.Join(productsDirname, entry.Name()))
		if err != nil {
			return err
		}
		var data []byte

		if _, err := file.Read(data); err != nil {
			return err
		}

		var products []Product

		if err := json.Unmarshal(data, &products); err != nil {
			return err
		}

		s.fillDB(products)
	}

	return nil

}

func (s *impl) ListProducts(ctx context.Context, _ int) ([]Product, error) {
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
	p, ok := s.db[productID]
	if !ok {
		return Product{}, NotFoundError{}
	}
	return p, nil
}

func (s *impl) GetProducts(ctx context.Context, productIDs []string, _ int) ([]Product, error) {
	products := make([]Product, len(productIDs))
	for i, pid := range productIDs {
		p, ok := s.db[pid]
		if !ok {
			return nil, NotFoundError{}
		}
		products[i] = p
	}
	return products, nil
}

func (s *impl) SearchProducts(ctx context.Context, query string, _ int) ([]Product, error) {
	// Interpret query as a substring match in name or description.
	var ps []Product
	i := 0
	q := strings.ToLower(query)
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

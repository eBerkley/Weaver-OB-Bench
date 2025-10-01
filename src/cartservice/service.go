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

package cartservice

import (
	"context"
	"fmt"
	"time"

	"github.com/eberkley/weaver"
	"github.com/redis/go-redis/v9"
	_ "go.uber.org/automaxprocs"

	imetrics "github.com/eberkley/weaver/runtime/codegen"
)

type CartItem struct {
	weaver.AutoMarshal
	ProductID string `json:"product_id"`
	Quantity  int32  `json:"quantity"`
}

type CartService interface {
	AddItem(ctx context.Context, userID string, item CartItem) error
	GetCart(ctx context.Context, userID string) ([]CartItem, error)
	EmptyCart(ctx context.Context, userID string) error
}

type cartConfig struct {
	// RedisAddr string
	RedisRAddr string
	RedisWAddr string
}

type impl struct {
	weaver.Implements[CartService]
	weaver.WithConfig[cartConfig]
	// cache weaver.Ref[cartCache]
	store *cartStore
}

func (s *impl) Init(ctx context.Context) error {
	// client := redis.NewClient(&redis.Options{
	// 	Addr: s.Config().RedisAddr,
	// })
	redisRClient := redis.NewClient(&redis.Options{
		Addr:     s.Config().RedisRAddr,
		PoolSize: 100,
	})
	redisWClient := redis.NewClient(&redis.Options{
		Addr: s.Config().RedisWAddr,
	})

	var res string
	var err error
	// i := 0
	// for i = range 25 {
	// 	res, err = client.Ping(ctx).Result()
	// 	if err != nil {
	// 		s.Logger(ctx).Error("Init: redis.Ping", "err", err)
	// 	} else {
	// 		break
	// 	}

	// 	time.Sleep(time.Second)
	// }

	ping := func(c *redis.Client) (int, error) {
		i := 0
		for i = range 25 {
			res, err = c.Ping(ctx).Result()
			if err != nil {
				s.Logger(ctx).Error("Init: redis.Ping", "err", err)
			} else {
				return i, nil
			}

			time.Sleep(time.Second)
		}
		return i, err
	}
	i, err := ping(redisRClient)
	if err != nil {
		return fmt.Errorf("Could not connect to redisR in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged redisR.", "attempts", i, "response", res)
	}

	i, err = ping(redisWClient)
	if err != nil {
		return fmt.Errorf("Could not connect to redisW in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged redisW.", "attempts", i, "response", res)
	}

	store, err := newCartStore(s.Logger(ctx), redisRClient, redisWClient)
	s.store = store

	// go func() {
	// 	ticker := time.NewTicker(time.Second)
	// 	defer ticker.Stop()
	// 	for {
	// 		select {
	// 		case <-ctx.Done():
	// 			return
	// 		case <-ticker.C:
	// 			imetrics.GroupGoroutineFor(imetrics.ComponentLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService"}).Set(float64(goruntime.NumGoroutine()))
	// 		}
	// 	}
	// }()
	return err
}

// AddItem adds a given item to the user's cart.
func (s *impl) AddItem(ctx context.Context, userID string, item CartItem) error {

	initTime := time.Now()

	duration, err := s.store.AddItem(ctx, userID, item.ProductID, item.Quantity)
	internalLatency := time.Since(initTime) - duration

	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService", Method: "AddItem"}).Put(float64(internalLatency.Microseconds()))
	return err
}

// GetCart returns the items in the user's cart.
func (s *impl) GetCart(ctx context.Context, userID string) ([]CartItem, error) {
	initTime := time.Now()

	items, duration, err := s.store.GetCart(ctx, userID)

	internalLatency := time.Since(initTime) - duration
	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService", Method: "GetCart"}).Put(float64(internalLatency.Microseconds()))

	return items, err
}

// EmptyCart empties the user's cart.
func (s *impl) EmptyCart(ctx context.Context, userID string) error {
	initTime := time.Now()

	duration, err := s.store.EmptyCart(ctx, userID)

	internalLatency := time.Since(initTime) - duration
	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/cartservice/CartService", Method: "EmptyCart"}).Put(float64(internalLatency.Microseconds()))

	return err

}

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
	"log/slog"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

type cartStore struct {
	logger *slog.Logger
	// cache  cartCache
	// cache *redis.Client
	redisRClient *redis.Client
	redisWClient *redis.Client
}

// func newCartStore(logger *slog.Logger, cache *redis.Client) (*cartStore, error) {
func newCartStore(logger *slog.Logger, rcache *redis.Client, wcache *redis.Client) (*cartStore, error) {
	return &cartStore{logger: logger, redisRClient: rcache, redisWClient: wcache}, nil
}

func (c *cartStore) AddItem(ctx context.Context, userID, productID string, quantity int32) (duration time.Duration, err error) {
	epoch := time.Now()
	// err = c.cache.HIncrBy(ctx, userID, productID, int64(quantity)).Err()
	err = c.redisWClient.HIncrBy(ctx, userID, productID, int64(quantity)).Err()
	duration = time.Since(epoch)
	if err != nil && err != redis.Nil {
		c.logger.Error("AddItem: HIncrBy", "userID", userID, "productID", productID, "err", err)
		err = fmt.Errorf("cache.HIncrBy(%s, %s, %v): %w", userID, productID, quantity, err)
	}
	return
}

func (c *cartStore) EmptyCart(ctx context.Context, userID string) (time.Duration, error) {
	epoch := time.Now()
	// err := c.cache.Del(ctx, userID).Err()
	err := c.redisWClient.Del(ctx, userID).Err()
	duration := time.Since(epoch)
	if err != nil && err != redis.Nil {
		err = fmt.Errorf("cache.Del(%v): %w", userID, err)
		c.logger.Error("EmptyCart", "err", err)
	}
	return duration, err
}

func (c *cartStore) GetCart(ctx context.Context, userID string) ([]CartItem, time.Duration, error) {
	epoch := time.Now()
	cart := make([]CartItem, 0)
	// res, err := c.cache.HGetAll(ctx, userID).Result()
	res, err := c.redisRClient.HGetAll(ctx, userID).Result()
	duration := time.Since(epoch)
	if err == redis.Nil {
		return cart, duration, nil
	} else if err != nil {
		err = fmt.Errorf("cache.HGetAll(%v): %w", userID, err)
		c.logger.Error("GetCart", "err", err)
		return nil, duration, err
	}
	for k, v := range res {
		q, err := strconv.Atoi(v)
		if err != nil {
			err = fmt.Errorf("strconv.Atoi(%v) returned %w. cache.HGetAll returned %v", v, err, res)
			c.logger.Error("GetCart", "err", err)
			return nil, duration, err
		}
		item := CartItem{
			ProductID: k,
			Quantity:  int32(q),
		}
		cart = append(cart, item)
	}
	return cart, duration, nil
}

// BELOW is an implementation using just a string datatype.
// A user cart is stored as a json-serialization, and adding requires optimistic concurrency control stuff.

// func (c *cartStore) AddItem(ctx context.Context, userID, productID string, quantity int32) (duration time.Duration, err error) {

// 	c.logger.Info("AddItem called", "userID", userID, "productID", productID, "quantity", quantity)

// 	loop := 0
// 	epoch := time.Now()

// 	// Latency measurements happen within this func
// 	txf := func(tx *redis.Tx) error {

// 		duration += time.Since(epoch)
// 		epoch = time.Now()

// 		// get current value
// 		item, errl := tx.Get(ctx, userID).Result()
// 		if err == redis.Nil {
// 			item = ""
// 		} else if err != nil {
// 			return err
// 		}

// 		// update latency metric
// 		// storeLat += float64(time.Now().UnixMilli() - epoch.UnixMilli())
// 		epoch = time.Now()
// 		// process value
// 		var slice []CartItem
// 		if item != "" {
// 			if errl := json.Unmarshal([]byte(item), &slice); errl != nil {
// 				c.logger.Error("UpdateStoreSlice json unmarshal", "err", errl.Error())
// 				return errl
// 			}
// 		} else {
// 			slice = make([]CartItem, 0)
// 		}

// 		exists := false
// 		for k, v := range slice {
// 			if v.ProductID == productID {
// 				slice[k].Quantity += quantity

// 				exists = true
// 				break
// 			}
// 		}

// 		if !exists {
// 			slice = append(slice, CartItem{
// 				ProductID: productID,
// 				Quantity:  quantity,
// 			})
// 		}

// 		// Marshal new value
// 		newVal, errl := json.Marshal(slice)
// 		if errl != nil {
// 			c.logger.Error("UpdateStoreSlice json marshal", "err", errl.Error())
// 			return errl
// 		}
// 		duration += time.Since(epoch)
// 		epoch = time.Now()

// 		// Store operation, committed only if watched key unchanged.
// 		_, err := tx.TxPipelined(ctx, func(pipe redis.Pipeliner) error {
// 			pipe.Set(ctx, userID, newVal, 0)
// 			return nil
// 		})

// 		// storeLat += float64(time.Now().UnixMilli() - epoch.UnixMilli())

// 		return err
// 	}

// 	// try until success or getting error other than concurrency failure
// 	for {
// 		loop += 1
// 		// quit if executed too many times
// 		if loop >= 100 {
// 			err = errors.New("UpdateStoreSlice loop exceeds 100 rounds, quitted")
// 			return
// 		}

// 		errl := c.cache.Watch(ctx, txf, userID)

// 		// item, errl := client.GetState(ctx, storeName, key)
// 		if errl == redis.TxFailedErr {
// 			// gotta try again.
// 			continue
// 		} else if errl != nil {
// 			c.logger.Error("UpdateStoreSlice GetState", "err", errl.Error())
// 			err = errl
// 			return
// 		}
// 		return
// 		// Success!
// 		// succ = true
// 	}

// }

// func (c *cartStore) EmptyCart(ctx context.Context, userID string) (time.Duration, error) {
// 	c.logger.Info("EmptyCart called", "userID", userID)
// 	removeTime := time.Now()

// 	err := c.cache.Del(ctx, userID).Err()
// 	if err != nil {
// 		c.logger.Error("cache.Del", "userId", userID, "err", err)
// 	}
// 	// _, err := c.cache.Remove(ctx, userID)

// 	return time.Since(removeTime), err
// }

// func (c *cartStore) GetCart(ctx context.Context, userID string) ([]CartItem, time.Duration, error) {
// 	c.logger.Info("GetCart called", "userID", userID)
// 	getTime := time.Now()

// 	var cart []CartItem
// 	cartStr, err := c.cache.Get(ctx, userID).Result()
// 	duration := time.Since(getTime)

// 	if err == redis.Nil {
// 		cart = make([]CartItem, 0)

// 	} else if err != nil {
// 		c.logger.Error("cache.Get", "userId", userID, "err", err)
// 		return nil, duration, err
// 	} else { // all clear

// 		if err := json.Unmarshal([]byte(cartStr), &cart); err != nil {
// 			c.logger.Error("GetCart: json.Unmarshal", "cartStr", cartStr, "err", err)
// 			return nil, duration, err
// 		}
// 	}

// 	return cart, duration, err
// }

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
	"time"

	"embed"
	"fmt"

	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	"github.com/redis/go-redis/v9"
	"go.opentelemetry.io/otel/trace"

	// "go.mongodb.org/mongo-driver/mongo"
	// "go.mongodb.org/mongo-driver/mongo/options"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"go.mongodb.org/mongo-driver/v2/mongo/readpref"
	_ "go.uber.org/automaxprocs"
)

const (
	maxProducts = 10
)

var (
	//go:embed products/*
	catalogFileData embed.FS
)

var (
	listProductsFilter = mongo.Pipeline{
		bson.D{{
			Key: "$sample",
			Value: bson.D{{
				Key:   "size",
				Value: maxProducts,
			}},
		}},
	}
	nearest = options.Collection().SetReadPreference(readpref.Nearest())
)

type Product struct {
	weaver.AutoMarshal
	ID          string  `json:"id" bson:"id"`
	Name        string  `json:"name" bson:"name"`
	Description string  `json:"description" bson:"description"`
	Picture     string  `json:"picture" bson:"picture"`
	PriceUSD    money.T `json:"priceUsd" bson:"priceUsd"`

	// Categories such as "clothing" or "kitchen" that can be used to look up
	// other related products.
	Categories []string `json:"categories" bson:"categories"`
}

type ProductCatalogService interface {
	ListProducts(ctx context.Context) ([]Product, error)
	GetProduct(ctx context.Context, productID string) (Product, error)
	GetProducts(ctx context.Context, productIDs []string) ([]Product, error)
	SearchProducts(ctx context.Context, query string, category string) ([]Product, error)
}

type productCatalogConfig struct {
	MongoURI          string
	ProductDatabase   string
	ProductCollection string
	MongoUser         string
	MongoPassword     string
	RedisRAddr        string
	RedisWAddr        string
	// RedisAddr         string
	// RedisAddrs []string
}

type impl struct {
	weaver.Implements[ProductCatalogService]
	weaver.WithConfig[productCatalogConfig]

	mongoClient *mongo.Client
	// redisClient *redis.ClusterClient
	// redisClient *redis.Client
	redisRClient *redis.Client
	redisWClient *redis.Client
}

var _ ProductCatalogService = (*impl)(nil)

func (s *impl) Init(ctx context.Context) error {
	// Addrs: s.Config().RedisAddrs,
	// s.redisClient = redis.NewClusterClient(&redis.ClusterOptions{
	// 	ReadOnly:       true,
	// 	Addrs:          []string{s.Config().RedisAddr},
	// 	RouteByLatency: true,
	// })
	// s.redisClient = redis.NewClient(&redis.Options{
	// 	Addr: s.Config().RedisAddr,
	// })
	s.redisRClient = redis.NewClient(&redis.Options{
		Addr:     s.Config().RedisRAddr,
		PoolSize: 200,
	})
	s.redisWClient = redis.NewClient(&redis.Options{
		Addr: s.Config().RedisWAddr,
	})
	s.Logger(ctx).Info("In Init function", "raddr", s.Config().RedisRAddr, "waddr", s.Config().RedisWAddr)
	var res string
	var err error

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

	i, err := ping(s.redisRClient)
	if err != nil {
		return fmt.Errorf("Could not connect to redisR in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged redisR.", "attempts", i, "response", res)
	}
	i, err = ping(s.redisWClient)
	if err != nil {
		return fmt.Errorf("Could not connect to redisW in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged redisW.", "attempts", i, "response", res)
	}

	uri := fmt.Sprintf("mongodb+srv://%s:%s@%s/?tls=false&authSource=admin", s.Config().MongoUser, s.Config().MongoPassword, s.Config().MongoURI)
	s.Logger(ctx).Info("Preparing to try to connect to Mongo", "uri", uri)
	serverAPI := options.ServerAPI(options.ServerAPIVersion1)
	opts := options.Client().
		ApplyURI(uri).
		SetServerAPIOptions(serverAPI).
		SetReadPreference(readpref.Nearest()).
		SetTimeout(time.Second * 30)

	s.mongoClient, err = mongo.Connect(opts)
	if err != nil {
		return fmt.Errorf("mongo.Connect: %w", err)
	}

	for i = range 25 {
		err = s.mongoClient.Ping(ctx, nil)
		if err != nil {
			s.Logger(ctx).Error("Init: mongo.Ping", "err", err)
		} else {
			break
		}

		time.Sleep(time.Second)
	}

	if err != nil {
		return fmt.Errorf("Could not connect to mongo in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged mongo.", "attempts", i)
	}
	return nil
}

// We get these from redis if possible,
// But if we don't get 10 unique prod-keys we get from mongo.
func (s *impl) ListProducts(ctx context.Context) ([]Product, error) {
	// sl, _ := s.redisClient.ClusterSlots(ctx).Result()
	// s.redisClient.ClusterGetKeysInSlot(ctx, 0, maxProducts*2)

	pl := s.redisRClient.Pipeline()
	for range maxProducts + 2 {
		pl.RandomKey(ctx)
	}
	rnd := make(map[string]struct{})
	span := trace.SpanFromContext(ctx)
	span.AddEvent("RandomKey-Start")
	cmds, err := pl.Exec(ctx)
	span.AddEvent("RandomKey-End")
	for _, cmd := range cmds {

		v, err := cmd.(*redis.StringCmd).Result()

		if err != nil || v[len(v)-3:] != "-pr" {
			// s.Logger(ctx).Info("ListProducts: got bad key")
			break
		}
		rnd[v] = struct{}{}
	}

	results := make([]Product, 0)
	if len(rnd) >= maxProducts {
		keys := make([]string, 0, maxProducts)
		for k := range rnd {
			keys = append(keys, k)
		}
		span.AddEvent("Redis-R-Start")
		prods, err := s.redisRClient.MGet(ctx, keys...).Result()
		span.AddEvent("Redis-R-End")
		if err != nil {
			return nil, err
		}
		for _, prod := range prods {
			str, ok := prod.(string)
			// Happens if in time between getting the keys and getting their values,
			// one of the keys got evicted.
			if !ok {
				// s.Logger(ctx).Info("ListProducts: unlikely cache miss")
				continue
			}
			var p Product
			json.Unmarshal([]byte(str), &p)
			results = append(results, p)
		}

		if len(results) >= maxProducts {
			// s.Logger(ctx).Info("ListProducts: Got all data from redis")
			return results[:maxProducts], nil
		} else {
			results = make([]Product, 0)
		}
	}

	s.Logger(ctx).Info("ListProducts: Did NOT get all data from redis")

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)

	span.AddEvent("Mongo-Start")
	cur, err := col.Aggregate(ctx, listProductsFilter)
	span.AddEvent("Mongo-End")

	if err != nil {
		s.Logger(ctx).Error("ListProduct: Aggregate", "query", listProductsFilter, "err", err)
		return nil, fmt.Errorf("Aggregate: %v", err)
	}

	if err = cur.All(ctx, &results); err != nil {
		s.Logger(ctx).Error("ListProduct: cursor.All", "err", err)
		return nil, fmt.Errorf("cursor.All: %v", err)
	}

	return results, nil
}

func (s *impl) GetProduct(ctx context.Context, productID string) (Product, error) {

	var p Product
	span := trace.SpanFromContext(ctx)
	rKey := redisProductKey(productID)
	span.AddEvent("Redis-R-Start")
	red, err := s.redisRClient.Get(ctx, rKey).Result()
	span.AddEvent("Redis-R-End")
	if err == nil {
		json.Unmarshal([]byte(red), &p)
		return p, nil

	} else if err != redis.Nil {
		s.Logger(ctx).Error("Error with Redis. Will continue...", "err", err, "id", rKey)
	} else {
		s.Logger(ctx).Warn("GetProduct: Cache miss", "id", rKey)
	}

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)
	filter := bson.D{
		{Key: "id", Value: productID},
	}
	span.AddEvent("Mongo-Start")
	err = col.FindOne(ctx, filter).Decode(&p)
	span.AddEvent("Mongo-End")
	if err != nil {
		s.Logger(ctx).Error("GetProduct: col.FindOne.Decode", "filter", filter, "err", err)
		return Product{}, fmt.Errorf("FindOne.Decode: %v", err.Error())
	}

	// Put into redis
	item, err := json.Marshal(p)
	if err != nil {
		err = fmt.Errorf("json.Marshal(%v): %w", p, err)
		s.Logger(ctx).Error("Get Product", "err", err)
		return p, err
	}

	span.AddEvent("Redis-W-Start")
	err = s.redisWClient.Set(ctx, rKey, string(item), 0).Err()
	span.AddEvent("Redis-W-End")
	if err != nil {
		s.Logger(ctx).Error("GetProduct: redis.Set", "err", err, "key", rKey)
	}

	return p, err
}

func (s *impl) GetProducts(ctx context.Context, productIDs []string) ([]Product, error) {

	found := make([]Product, 0)
	if len(productIDs) == 0 {
		// s.Logger(ctx).Info("GetProducts got empty productIDs...")
		return found, nil
	}
	missing := make([]string, 0)
	redIDs := make([]string, len(productIDs))

	// redIDs := make(map[int64][]string, len(productIDs))

	// for _, p := range productIDs {
	// 	k := redisProductKey(p)
	// 	slot, _ := s.redisClient.ClusterKeySlot(ctx, k).Result()
	// 	redIDs[slot] = append(redIDs[slot], k)
	// }

	// for _, ks := range redIDs {
	// 	res, err := s.redisClient.MGet(ctx, ks...).Result()
	// 	if err != nil && err != redis.Nil {
	// 		s.Logger(ctx).Error("GetProducts: Problem with Redis. Will continue...", "err", err, "ids", ks)
	// 		missing = append(missing, productIDs...)
	// 		break
	// 	} else {
	// 		for j, it := range res {
	// 			// it = string | nil
	// 			str, ok := it.(string)
	// 			if !ok {
	// 				// it = nil, so value is missing
	// 				realVal := ks[j][0 : len(ks[j])-3]
	// 				missing = append(missing, realVal)
	// 				continue
	// 			}
	// 			var p Product
	// 			err := json.Unmarshal([]byte(str), &p)
	// 			if err != nil {
	// 				s.Logger(ctx).Error("Redis unmarshal", "err", err, "value", str)
	// 				realVal := ks[j][0 : len(ks[j])-3]
	// 				missing = append(missing, realVal)
	// 				continue
	// 			}

	// 			found = append(found, p)
	// 		}
	// 	}
	// }

	for i, p := range productIDs {
		redIDs[i] = redisProductKey(p)
	}

	span := trace.SpanFromContext(ctx)
	span.AddEvent("Redis-R-Start")
	res, err := s.redisRClient.MGet(ctx, redIDs...).Result()
	span.AddEvent("Redis-R-End")

	if err != nil && err != redis.Nil {
		s.Logger(ctx).Error("GetProducts: Problem with Redis. Will continue...", "err", err, "ids", redIDs)
		missing = productIDs

	} else {
		for i, it := range res {
			// it = string | nil
			str, ok := it.(string)
			if !ok {
				// it = nil, so value is missing
				missing = append(missing, productIDs[i])
				continue
			}
			var p Product
			err := json.Unmarshal([]byte(str), &p)
			if err != nil {
				s.Logger(ctx).Error("Redis unmarshal", "err", err, "value", str)
				missing = append(missing, productIDs[i])
				continue
			}

			found = append(found, p)
		}
	}

	// No cache misses
	if len(missing) == 0 {
		// s.Logger(ctx).Info("GetProducts completed successfully", "numProducts", len(productIDs))
		return found, nil
	}

	s.Logger(ctx).Warn("GetProducts: cache miss", "numIDs", len(productIDs), "num missing", len(missing))

	// Have to fetch some data from mongo...
	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)

	filter := bson.D{{
		Key: "id",
		Value: bson.D{{
			Key:   "$in",
			Value: missing,
		}},
	}}
	span.AddEvent("Mongo-Start")
	cur, err := col.Find(ctx, filter)
	span.AddEvent("Mongo-End")
	if err != nil {
		s.Logger(ctx).Error("GetProducts: col.Find", "filter", filter, "err", err)
		return nil, fmt.Errorf("Find: %v", err.Error())
	}
	var ps []Product
	if err := cur.All(ctx, &ps); err != nil {
		s.Logger(ctx).Error("GetProducts: cursor.All", "err", err)
		return nil, fmt.Errorf("cursor.All: %v", err.Error())
	}

	if len(ps) != len(missing) {
		err = fmt.Errorf("mongo.Get: missing data: expected %d, got %d", len(missing), len(ps))
		s.Logger(ctx).Error("GetProducts: mongo.Get: missing data", "expected", len(missing), "got", len(ps), "missingIDs", missing)
		return nil, err
	}

	// ps now has all the missing data.
	// We have to send a separate memcached.Set req for each key,

	redisSet := make(map[string]string)
	for _, p := range ps {
		b, err := json.Marshal(p)
		if err != nil {
			s.Logger(ctx).Error("json.Marshal", "err", err, "product", p)
			return nil, err
		}
		k := redisProductKey(p.ID)
		redisSet[k] = string(b)
	}
	span.AddEvent("Redis-W-Start")
	err = s.redisWClient.MSet(ctx, redisSet).Err()
	span.AddEvent("Redis-W-End")
	if err != nil {
		err = fmt.Errorf("redis.MSet(%v): %w", redisSet, err)
		s.Logger(ctx).Error("GetProducts", "err", err)
	}

	// redisSet := make(map[int64]map[string]string)
	// for _, p := range ps {
	// 	b, err := json.Marshal(p)
	// 	if err != nil {
	// 		s.Logger(ctx).Error("json.Marshal", "err", err, "product", p)
	// 		return nil, err
	// 	}
	// 	k := redisProductKey(p.ID)
	// 	slot, _ := s.redisClient.ClusterKeySlot(ctx, k).Result()
	// 	if redisSet[slot] == nil {
	// 		redisSet[slot] = make(map[string]string)
	// 	}
	// 	redisSet[slot][k] = string(b)
	// }
	// for _, set := range redisSet {
	// 	err = s.redisClient.MSet(ctx, set).Err()
	// 	if err != nil {
	// 		err = fmt.Errorf("redis.MSet(%v): %w", set, err)
	// 		s.Logger(ctx).Error("GetProducts", "err", err)
	// 	}
	// }

	return append(found, ps...), err
}

func (s *impl) SearchProducts(ctx context.Context, query string, category string) ([]Product, error) {
	var ps []Product
	logger := s.Logger(ctx).With("method", "SearchProducts", "q", query, "category", category)
	if query == "" && category == "" {
		return []Product{}, nil
	}

	rKey := redisSearchKey(query, category)

	// Check in Redis
	span := trace.SpanFromContext(ctx)
	span.AddEvent("Redis-R-Start")
	redisResult, err := s.redisRClient.Get(ctx, rKey).Result()
	span.AddEvent("Redis-R-End")

	if err == nil {

		err = json.Unmarshal([]byte(redisResult), &ps)

		if err != nil {
			err = fmt.Errorf("SearchProducts: json.Unmarshal(redis): %v, redisResult: %v", err, redisResult)
			logger.Error(err.Error())
			return nil, err
		}
		// logger.Info("found in redis.", "len", len(ps))
		return ps, nil

	} else if err != redis.Nil {
		logger.Error("SearchProducts: redis.Get. Continuing...", "err", err, "key", rKey)
	} else {
		logger.Warn("SearchProducts: Cache miss", "key", rKey)
	}

	// not in redis

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection, nearest)

	// filter := bson.D{
	// 	{Key: "name", Value: bson.D{
	// 		{Key: "$regex", Value: query},
	// 	}},
	// }
	var filter bson.D

	if category == "" {
		filter = bson.D{{
			Key: "$text",
			Value: bson.D{{
				Key:   "$search",
				Value: query,
			}},
		}}
	} else if query == "" {
		filter = bson.D{{
			Key:   "categories",
			Value: category,
		}}
	} else {
		filter = bson.D{
			{
				Key:   "$text",
				Value: bson.D{{Key: "$search", Value: query}},
			}, {
				Key:   "categories",
				Value: category,
			},
		}
	}

	opts := options.Find().SetLimit(maxProducts)

	span.AddEvent("Mongo-Start")
	cur, err := col.Find(ctx, filter, opts)
	span.AddEvent("Mongo-End")
	if err != nil {
		s.Logger(ctx).Error("SearchProducts: col.Find", "filter", filter, "err", err)
		return nil, fmt.Errorf("Find: %v", err.Error())
	}

	if err := cur.All(ctx, &ps); err != nil {
		s.Logger(ctx).Error("SearchProducts: cursor.All", "err", err)
		return nil, fmt.Errorf("cursor.All: %v", err.Error())
	}

	// Add to redis
	bs, err := json.Marshal(ps)
	if err != nil {
		s.Logger(ctx).Error("SearchProducts: Marshal redis value", "err", err)
		return ps, err
	}
	span.AddEvent("Redis-W-Start")
	err = s.redisWClient.Set(ctx, rKey, string(bs), 0).Err()
	span.AddEvent("Redis-W-End")
	if err != nil {
		s.Logger(ctx).Error("SearchProducts: set redis value", "err", err, "key", rKey, "val", string(bs))
		return ps, err
	}

	return ps, nil
}

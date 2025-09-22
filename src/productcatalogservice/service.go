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
	SearchProducts(ctx context.Context, query string) ([]Product, error)
}

type productCatalogConfig struct {
	MongoURI          string
	ProductDatabase   string
	ProductCollection string
	MongoUser         string
	MongoPassword     string
	RedisAddr         string
}

type impl struct {
	weaver.Implements[ProductCatalogService]
	weaver.WithConfig[productCatalogConfig]

	mongoClient *mongo.Client
	redisClient *redis.ClusterClient // *redis.Client
}

var _ ProductCatalogService = (*impl)(nil)

func (s *impl) Init(ctx context.Context) error {
	s.redisClient = redis.NewClusterClient(&redis.ClusterOptions{
		ReadOnly:       true,
		Addrs:          []string{s.Config().RedisAddr},
		RouteByLatency: true,
	})

	var res string
	var err error
	i := 0
	for i = range 25 {
		res, err = s.redisClient.Ping(ctx).Result()
		if err != nil {
			s.Logger(ctx).Error("Init: redis.Ping", "err", err)
		} else {
			break
		}

		time.Sleep(time.Second)
	}

	if err != nil {
		return fmt.Errorf("Could not connect to redis in 25 tries. Err: %w", err)
	} else {
		s.Logger(ctx).Info("Successfully pinged redis.", "attempts", i, "response", res)
	}

	uri := fmt.Sprintf("mongodb+srv://%s:%s@%s/?tls=false&authSource=admin", s.Config().MongoUser, s.Config().MongoPassword, s.Config().MongoURI)
	s.Logger(ctx).Info("Preparing to try to connect to Mongo", "uri", uri)
	serverAPI := options.ServerAPI(options.ServerAPIVersion1)
	opts := options.Client().
		ApplyURI(uri).
		SetServerAPIOptions(serverAPI).
		SetReadPreference(readpref.Nearest()).
		SetTimeout(time.Second * 2)

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

	pl := s.redisClient.Pipeline()
	for range maxProducts {
		pl.RandomKey(ctx)
	}
	rnd := make(map[string]struct{})
	cmds, err := pl.Exec(ctx)
	for _, cmd := range cmds {

		v, err := cmd.(*redis.StringCmd).Result()

		if err != nil || v[len(v)-3:] != "-pr" {
			break
		}
		rnd[v] = struct{}{}
	}

	results := make([]Product, 0)
	if len(rnd) == maxProducts {
		keys := make([]string, 0, maxProducts)
		for k := range rnd {
			keys = append(keys, k)
		}
		prods, err := s.redisClient.MGet(ctx, keys...).Result()
		if err != nil {
			return nil, err
		}
		for _, prod := range prods {
			str, ok := prod.(string)
			// Happens if in time between getting the keys and getting their values,
			// one of the keys got evicted.
			if !ok {
				break
			}
			var p Product
			json.Unmarshal([]byte(str), &p)
			results = append(results, p)
		}

		if len(results) == maxProducts {
			return results, nil
		} else {
			results = make([]Product, 0)
		}
	}

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)
	cur, err := col.Aggregate(ctx, listProductsFilter)

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
	red, err := s.redisClient.Get(ctx, redisProductKey(productID)).Result()
	if err == nil {
		json.Unmarshal([]byte(red), &p)
		return p, nil

	} else if err != redis.Nil {
		s.Logger(ctx).Error("Error with Redis. Will continue...", "err", err, "id", productID)
	} else {
		s.Logger(ctx).Error("GetProduct: Not in redis", "id", productID)
	}

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)
	filter := bson.D{
		{Key: "id", Value: productID},
	}

	err = col.FindOne(ctx, filter).Decode(&p)
	if err != nil {
		s.Logger(ctx).Error("GetProduct: col.FindOne.Decode", "filter", filter, "err", err)
		return Product{}, fmt.Errorf("FindOne.Decode: %v", err.Error())
	}

	// Put into memcache
	// We assume no err, since we could decode just fine...
	item, _ := json.Marshal(p)
	s.redisClient.Set(ctx, redisProductKey(productID), item, 0)

	return p, nil
}

func (s *impl) GetProducts(ctx context.Context, productIDs []string) ([]Product, error) {

	found := make([]Product, 0)
	if len(productIDs) == 0 {
		return found, nil
	}
	missing := make([]string, 0)

	redIDs := make([]string, len(productIDs))
	for i, p := range productIDs {
		redIDs[i] = redisProductKey(p)
	}
	res, err := s.redisClient.MGet(ctx, redIDs...).Result()

	if err != nil && err != redis.Nil {
		s.Logger(ctx).Error("Problem with Redis. Will continue...", "err", err, "ids", productIDs)

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
		return found, nil
	}

	s.Logger(ctx).Info("GetProducts: cache miss", "numIDs", len(productIDs), "num missing", len(missing))

	// Have to fetch some data from mongo...
	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection)

	filter := bson.D{{
		Key: "id",
		Value: bson.D{{
			Key:   "$in",
			Value: missing,
		}},
	}}

	cur, err := col.Find(ctx, filter)
	if err != nil {
		s.Logger(ctx).Error("GetProducts: col.Find", "filter", filter, "err", err)
		return nil, fmt.Errorf("Find: %v", err.Error())
	}
	var ps []Product
	if err := cur.All(ctx, &ps); err != nil {
		s.Logger(ctx).Error("GetProducts: cursor.All", "err", err)
		return nil, fmt.Errorf("cursor.All: %v", err.Error())
	}

	// ps now has all the missing data.
	// We have to send a separate memcached.Set req for each key,
	//	so we do it in the background.
	redisSet := make(map[string]string)
	for _, p := range ps {
		b, err := json.Marshal(p)
		if err != nil {
			s.Logger(ctx).Error("json.Marshal", "err", err, "product", p)
			return nil, err
		}
		redisSet[redisProductKey(p.ID)] = string(b)
	}
	err = s.redisClient.MSet(ctx, redisSet).Err()

	return append(found, ps...), nil
}

func (s *impl) SearchProducts(ctx context.Context, query string) ([]Product, error) {
	var ps []Product

	// Check in Redis
	redisResult, err := s.redisClient.Get(ctx, redisSearchKey(query)).Result()
	if err == nil {

		err = json.Unmarshal([]byte(redisResult), &ps)

		if err != nil {
			err = fmt.Errorf("SearchProducts: json.Unmarshal(redis): %v, redisResult: %v", err, redisResult)
			s.Logger(ctx).Error(err.Error())
			return nil, err
		}
		return ps, nil

	} else if err != redis.Nil {
		s.Logger(ctx).Error("SearchProducts: redis.Get. Continuing...", "err", err, "query", redisSearchKey(query))
	} else {
		s.Logger(ctx).Info("SearchProducts: not in redis", "query", query)
	}

	// not in redis

	col := s.mongoClient.Database(s.Config().ProductDatabase).Collection(s.Config().ProductCollection, nearest)

	filter := bson.D{
		{Key: "name", Value: bson.D{
			{Key: "$regex", Value: query},
		}},
	}

	opts := options.Find().SetLimit(maxProducts)

	cur, err := col.Find(ctx, filter, opts)
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

	err = s.redisClient.Set(ctx, redisSearchKey(query), string(bs), 0).Err()
	if err != nil {
		s.Logger(ctx).Error("SearchProducts: set redis value", "err", err, "key", redisSearchKey(query), "val", string(bs))
		return ps, err
	}

	return ps, nil
}

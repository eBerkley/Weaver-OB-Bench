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

package checkoutservice

import (
	"context"
	"fmt"
	"strings"
	"time"
	goruntime "runtime"

	"github.com/eBerkley/Weaver-OB-Bench/cartservice"
	"github.com/eBerkley/Weaver-OB-Bench/paymentservice"
	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice"
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice"
	"github.com/eBerkley/Weaver-OB-Bench/types"
	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	"github.com/eberkley/weaver/runtime"
	imetrics "github.com/eberkley/weaver/runtime/codegen"

	_ "go.uber.org/automaxprocs"
)

type PlaceOrderRequest struct {
	weaver.AutoMarshal
	UserID       string
	UserCurrency string
	Address      shippingservice.Address
	Email        string
	CreditCard   paymentservice.CreditCardInfo
}

type FullCheckoutService interface {
	PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, []productcatalogservice.Product, error)
}

type SimpleCheckoutService interface {
	PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, error)
}

func (s *impl) Init(ctx context.Context) error {

	if s.catalogReplicas == 0 {
		s.catalogReplicas = productcatalogservice.ProductCatalogReplicas
	}

	s.UpdateCatalogService(ctx, s.catalogReplicas)

	go func() {
		ticker := time.NewTicker(time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				imetrics.GroupGoroutineFor(imetrics.ComponentLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService"}).Set(float64(goruntime.NumGoroutine()))
			}
		}
	}()


	return nil
}

func (s *impl) UpdateCatalogService(ctx2 context.Context, replicas int) {
	ctx, cancelFn := context.WithCancel(ctx2)

	if s.cancelFn != nil {
		s.cancelFn()
	}
	s.cancelFn = cancelFn

	updateCatalogInfo := func() {
		s.catalogMu.Lock()
		s.catalogReplicas = replicas
		s.catalogInit = true
		s.catalogMu.Unlock()
	}

	if !s.catalogInit {
		updateCatalogInfo()
		s.catalogInit = true
		return
	}

	timer := time.NewTimer(time.Duration(20) * time.Second)
	go func() {
		select {
		case <-timer.C:
			updateCatalogInfo()

		case <-ctx.Done():

		}

	}()

}

func (s *impl) UpdateRoutingHook(ctx context.Context, componentName string, replicas int) error {

	if !strings.HasSuffix(componentName, "ProductCatalogService") {
		if strings.HasSuffix(componentName, "CheckoutService") {
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

type orderPrep struct {
	orderItems            []types.OrderItem
	cartItems             []cartservice.CartItem
	shippingCostLocalized money.T
}

func (s *impl) prepareOrderItemsAndShippingQuoteFromCart(ctx context.Context, userID, userCurrency string, address shippingservice.Address) (out orderPrep, duration time.Duration, err error) {

	getCartTime := time.Now()
	cartItems, err := s.cartService.Get().GetCart(ctx, userID)
	duration += time.Since(getCartTime)

	if err != nil {
		err = fmt.Errorf("failed to get user cart during checkout: %w", err)
		return
	}

	var orderItems []types.OrderItem
	var d time.Duration
	orderItems, d, err = s.prepOrderItems(ctx, cartItems, userCurrency)
	duration += d

	if err != nil {
		err = fmt.Errorf("failed to prepare order: %w", err)
		return
	}

	getQuoteTime := time.Now()
	shippingUSD, err := s.shippingService.Get().GetQuote(ctx, address, cartItems)
	duration += time.Since(getQuoteTime)

	if err != nil {
		err = fmt.Errorf("failed to get shipping quote: %w", err)
		return
	}
	convertTime := time.Now()
	shippingPrice, err := s.currencyService.Get().Convert(ctx, shippingUSD, userCurrency)
	duration += time.Since(convertTime)

	if err != nil {
		err = fmt.Errorf("failed to convert shipping cost to currency: %w", err)
		return
	}

	out.shippingCostLocalized = shippingPrice
	out.cartItems = cartItems
	out.orderItems = orderItems
	return
}

func (s *impl) prepOrderItems(ctx context.Context, items []cartservice.CartItem, userCurrency string) (out []types.OrderItem, duration time.Duration, err error) {
	out = make([]types.OrderItem, len(items))
	s.catalogMu.RLock()
	repls := s.catalogReplicas
	s.catalogMu.RUnlock()
	for i, item := range items {
		var product productcatalogservice.Product

		s.catalogMu.RLock()
		shard := productcatalogservice.HashProductID(item.ProductID, repls)
		s.catalogMu.RUnlock()

		getProductTime := time.Now()
		product, err = s.catalogService.Get().GetProduct(ctx, item.ProductID, shard)
		duration += time.Since(getProductTime)

		if err != nil {
			err = fmt.Errorf("failed to get product #%q: %w", item.ProductID, err)
			return
		}
		var price money.T

		convertTime := time.Now()
		price, err = s.currencyService.Get().Convert(ctx, product.PriceUSD, userCurrency)
		duration += time.Since(convertTime)

		if err != nil {
			err = fmt.Errorf("failed to convert price of %q to %s: %w", item.ProductID, userCurrency, err)
			return
		}
		out[i] = types.OrderItem{
			Item: item,
			Cost: price,
		}
	}

	return
}

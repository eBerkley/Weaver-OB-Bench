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
	"time"

	"github.com/eBerkley/Weaver-OB-Bench/cartservice"
	"github.com/eBerkley/Weaver-OB-Bench/currencyservice"
	"github.com/eBerkley/Weaver-OB-Bench/emailservice"
	"github.com/eBerkley/Weaver-OB-Bench/paymentservice"
	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice"
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice"
	"github.com/eBerkley/Weaver-OB-Bench/types"
	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	imetrics "github.com/eberkley/weaver/runtime/codegen"
	"github.com/google/uuid"

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

type CheckoutService interface {
	PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, error)
}

type impl struct {
	weaver.Implements[CheckoutService]

	catalogService  weaver.Ref[productcatalogservice.ProductCatalogService]
	cartService     weaver.Ref[cartservice.CartService]
	currencyService weaver.Ref[currencyservice.CurrencyService]
	shippingService weaver.Ref[shippingservice.ShippingService]
	emailService    weaver.Ref[emailservice.EmailService]
	paymentService  weaver.Ref[paymentservice.PaymentService]

	catalogRoutingTable productcatalogservice.ProductRoutingTable
}

func (s *impl) Init(ctx context.Context) error {
	s.catalogRoutingTable = productcatalogservice.GetRoutingTable(&s.catalogService)
	return nil
}

func (s *impl) PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, error) {
	initTime := time.Now()

	s.Logger(ctx).Info("[PlaceOrder]", "user_id", req.UserID, "user_currency", req.UserCurrency)

	prep, duration, err := s.prepareOrderItemsAndShippingQuoteFromCart(ctx, req.UserID, req.UserCurrency, req.Address)
	if err != nil {
		return types.Order{}, err
	}

	total := money.T{
		CurrencyCode: req.UserCurrency,
		Units:        0,
		Nanos:        0,
	}
	total = money.Must(money.Sum(total, prep.shippingCostLocalized))
	for _, it := range prep.orderItems {
		multPrice := money.MultiplySlow(it.Cost, uint32(it.Item.Quantity))
		total = money.Must(money.Sum(total, multPrice))
	}

	chargeTime := time.Now()
	txID, err := s.paymentService.Get().Charge(ctx, total, req.CreditCard)
	duration += time.Since(chargeTime)

	if err != nil {
		return types.Order{}, fmt.Errorf("failed to charge card: %w", err)
	}
	s.Logger(ctx).Info("payment went through", "transaction_id", txID)

	shipOrderTime := time.Now()
	shippingTrackingID, err := s.shippingService.Get().ShipOrder(ctx, req.Address, prep.cartItems)
	duration += time.Since(shipOrderTime)

	if err != nil {
		return types.Order{}, fmt.Errorf("shipping error: %w", err)
	}

	cartTime := time.Now()
	_ = s.cartService.Get().EmptyCart(ctx, req.UserID)
	duration += time.Since(cartTime)

	order := types.Order{
		OrderID:            uuid.New().String(),
		ShippingTrackingID: shippingTrackingID,
		ShippingCost:       prep.shippingCostLocalized,
		ShippingAddress:    req.Address,
		Items:              prep.orderItems,
	}

	emailTime := time.Now()
	err = s.emailService.Get().SendOrderConfirmation(ctx, req.Email, order)
	duration += time.Since(emailTime)

	if err != nil {
		s.Logger(ctx).Error("failed to send order confirmation", "err", err, "email", req.Email)
	} else {
		s.Logger(ctx).Info("order confirmation email sent", "email", req.Email)
	}

	entireDuration := time.Since(initTime)
	internalLatency := entireDuration - duration
	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService", Method: "PlaceOrder"}).Put(float64(internalLatency.Microseconds()))

	return order, nil
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
	for i, item := range items {
		var product productcatalogservice.Product
		key := s.catalogRoutingTable[productcatalogservice.HashProductID(item.ProductID)]

		getProductTime := time.Now()
		product, err = s.catalogService.Get().GetProduct(ctx, item.ProductID, key)
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

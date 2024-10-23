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

	"github.com/ServiceWeaver/onlineboutique/cartservice"
	"github.com/ServiceWeaver/onlineboutique/currencyservice"
	"github.com/ServiceWeaver/onlineboutique/emailservice"
	"github.com/ServiceWeaver/onlineboutique/paymentservice"
	"github.com/ServiceWeaver/onlineboutique/productcatalogservice"
	"github.com/ServiceWeaver/onlineboutique/shippingservice"
	"github.com/ServiceWeaver/onlineboutique/types"
	"github.com/ServiceWeaver/onlineboutique/types/money"
	"github.com/ServiceWeaver/weaver"
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

	catalogService  weaver.Ref[productcatalogservice.CatalogService]
	cartService     weaver.Ref[cartservice.CartService]
	currencyService weaver.Ref[currencyservice.CurrencyService]
	shippingService weaver.Ref[shippingservice.ShippingService]
	emailService    weaver.Ref[emailservice.EmailService]
	paymentService  weaver.Ref[paymentservice.PaymentService]
}

func (s *impl) PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, error) {
	s.Logger(ctx).Info("[PlaceOrder]", "user_id", req.UserID, "user_currency", req.UserCurrency)

	prep, err := s.prepareOrderItemsAndShippingQuoteFromCart(ctx, req.UserID, req.UserCurrency, req.Address)
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

	txID, err := s.paymentService.Get().Charge(ctx, total, req.CreditCard)
	if err != nil {
		return types.Order{}, fmt.Errorf("failed to charge card: %w", err)
	}
	s.Logger(ctx).Info("payment went through", "transaction_id", txID)

	shippingTrackingID, err := s.shippingService.Get().ShipOrder(ctx, req.Address, prep.cartItems)
	if err != nil {
		return types.Order{}, fmt.Errorf("shipping error: %w", err)
	}

	_ = s.cartService.Get().EmptyCart(ctx, req.UserID)

	order := types.Order{
		OrderID:            uuid.New().String(),
		ShippingTrackingID: shippingTrackingID,
		ShippingCost:       prep.shippingCostLocalized,
		ShippingAddress:    req.Address,
		Items:              prep.orderItems,
	}

	if err := s.emailService.Get().SendOrderConfirmation(ctx, req.Email, order); err != nil {
		s.Logger(ctx).Error("failed to send order confirmation", "err", err, "email", req.Email)
	} else {
		s.Logger(ctx).Info("order confirmation email sent", "email", req.Email)
	}
	return order, nil
}

type orderPrep struct {
	orderItems            []types.OrderItem
	cartItems             []cartservice.CartItem
	shippingCostLocalized money.T
}

func (s *impl) prepareOrderItemsAndShippingQuoteFromCart(ctx context.Context, userID, userCurrency string, address shippingservice.Address) (orderPrep, error) {
	var out orderPrep
	cartItems, err := s.cartService.Get().GetCart(ctx, userID)
	if err != nil {
		return out, fmt.Errorf("failed to get user cart during checkout: %w", err)
	}
	orderItems, err := s.prepOrderItems(ctx, cartItems, userCurrency)
	if err != nil {
		return out, fmt.Errorf("failed to prepare order: %w", err)
	}
	shippingUSD, err := s.shippingService.Get().GetQuote(ctx, address, cartItems)
	if err != nil {
		return out, fmt.Errorf("failed to get shipping quote: %w", err)
	}
	shippingPrice, err := s.currencyService.Get().Convert(ctx, shippingUSD, userCurrency)
	if err != nil {
		return out, fmt.Errorf("failed to convert shipping cost to currency: %w", err)
	}

	out.shippingCostLocalized = shippingPrice
	out.cartItems = cartItems
	out.orderItems = orderItems
	return out, nil
}

func (s *impl) prepOrderItems(ctx context.Context, items []cartservice.CartItem, userCurrency string) ([]types.OrderItem, error) {
	out := make([]types.OrderItem, len(items))
	for i, item := range items {
		product, err := s.catalogService.Get().GetProduct(ctx, item.ProductID)
		if err != nil {
			return nil, fmt.Errorf("failed to get product #%q: %w", item.ProductID, err)
		}
		price, err := s.currencyService.Get().Convert(ctx, product.PriceUSD, userCurrency)
		if err != nil {
			return nil, fmt.Errorf("failed to convert price of %q to %s: %w", item.ProductID, userCurrency, err)
		}
		out[i] = types.OrderItem{
			Item: item,
			Cost: price,
		}
	}
	return out, nil
}

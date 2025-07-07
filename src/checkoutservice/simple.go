//go:build simple_checkout
// +build simple_checkout

package checkoutservice

import (
	"context"
	"fmt"
	"sync"
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
)

type CheckoutService interface {
	SimpleCheckoutService
}

type impl struct {
	weaver.Implements[CheckoutService]

	catalogService  weaver.Ref[productcatalogservice.ProductCatalogService]
	cartService     weaver.Ref[cartservice.CartService]
	currencyService weaver.Ref[currencyservice.CurrencyService]
	shippingService weaver.Ref[shippingservice.ShippingService]
	emailService    weaver.Ref[emailservice.EmailService]
	paymentService  weaver.Ref[paymentservice.PaymentService]

	catalogMu       sync.RWMutex
	catalogReplicas int
	catalogInit     bool
	cancelFn        context.CancelFunc
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

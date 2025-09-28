// //go:build full_checkout
// // +build full_checkout

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
	"github.com/eBerkley/Weaver-OB-Bench/recommendationservice"
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice"
	"github.com/eBerkley/Weaver-OB-Bench/types"
	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	"github.com/eberkley/weaver"
	"github.com/google/uuid"

	imetrics "github.com/eberkley/weaver/runtime/codegen"
)

type CheckoutService interface {
	FullCheckoutService
}

type impl struct {
	weaver.Implements[CheckoutService]

	catalogService  weaver.Ref[productcatalogservice.ProductCatalogService]
	cartService     weaver.Ref[cartservice.CartService]
	currencyService weaver.Ref[currencyservice.CurrencyService]
	shippingService weaver.Ref[shippingservice.ShippingService]
	emailService    weaver.Ref[emailservice.EmailService]
	paymentService  weaver.Ref[paymentservice.PaymentService]
	recService      weaver.Ref[recommendationservice.RecService]
}

func (s *impl) PlaceOrder(ctx context.Context, req PlaceOrderRequest) (types.Order, []productcatalogservice.Product, error) {
	initTime := time.Now()
	logger := s.Logger(ctx).With("user_id", req.UserID, "user_currency", req.UserCurrency)
	logger.Info("[PlaceOrder]")
	prep, duration, err := s.prepareOrderItemsAndShippingQuoteFromCart(ctx, req.UserID, req.UserCurrency, req.Address)
	if err != nil {
		return types.Order{}, nil, err
	}

	defer func() {
		logger.Info("Place Order complete. ", "total_duration", time.Since(initTime), "downstream_duration", duration)
	}()

	productIDs := make([]string, len(prep.orderItems))
	for i, p := range prep.orderItems {
		productIDs[i] = p.Item.ProductID
	}

	listRecsTime := time.Now()
	recommendationIDs, err := s.recService.Get().ListRecommendations(ctx, productIDs)

	duration += time.Since(listRecsTime)
	logger.Info("Got recommendations", "duration", time.Since(listRecsTime))
	if err != nil {
		return types.Order{}, nil, err
	}

	// out := make([]productcatalogservice.Product, 0, len(recommendationIDs))

	// s.catalogMu.RLock()
	// repls := s.catalogReplicas
	// s.catalogMu.RUnlock()

	// productShardMap := make([][]string, repls)

	getProductsTime := time.Now()
	out, err := s.catalogService.Get().GetProducts(ctx, recommendationIDs)
	duration += time.Since(getProductsTime)
	logger.Info("Got products", "duration", time.Since(getProductsTime))
	if err != nil {
		logger.Error("PlaceOrder: GetProducts", "recommendationIDs", recommendationIDs, "err", err)
		return types.Order{}, nil, fmt.Errorf("failed to get recommended product info: %w", err)
	}

	// for _, id := range recommendationIDs {
	// 	shard := productcatalogservice.HashProductID(id, repls)
	// 	productShardMap[shard] = append(productShardMap[shard], id)
	// }

	// we send an RPC to each replica serially, rather than concurrently.
	// for shard := 0; shard < repls; shard++ {

	// 	if len(productShardMap[shard]) == 0 {
	// 		continue
	// 	}

	// 	getProductsTime := time.Now()
	// 	prods, err := s.catalogService.Get().
	// 		GetProducts(ctx, productShardMap[shard], shard)
	// 	duration += time.Since(getProductsTime)

	// 	if err != nil {
	// 		return types.Order{}, nil, fmt.Errorf("failed to get recommended product info at shard %v: %w", shard, err)
	// 	}
	// 	out = append(out, prods...)
	// }
	if len(out) > 4 {
		out = out[:4] // take only first four to fit the UI
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
	logger.Info("made transaction", "duration", time.Since(chargeTime))

	if err != nil {
		return types.Order{}, nil, fmt.Errorf("failed to charge card: %w", err)
	}
	logger.Info("payment went through", "transaction_id", txID)

	shipOrderTime := time.Now()
	shippingTrackingID, err := s.shippingService.Get().ShipOrder(ctx, req.Address, prep.cartItems)
	duration += time.Since(shipOrderTime)
	logger.Info("Got shipping tracking ID", "duration", time.Since(shipOrderTime))

	if err != nil {
		return types.Order{}, nil, fmt.Errorf("shipping error: %w", err)
	}

	cartTime := time.Now()
	_ = s.cartService.Get().EmptyCart(ctx, req.UserID)
	duration += time.Since(cartTime)
	logger.Info("Emptied cart", "duration", time.Since(cartTime))
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
	logger.Info("Sent order confirmation email", "duration", time.Since(emailTime))

	if err != nil {
		logger.Error("failed to send order confirmation", "err", err, "email", req.Email)
	} else {
		logger.Info("order confirmation email sent", "email", req.Email)
	}

	entireDuration := time.Since(initTime)
	internalLatency := entireDuration - duration
	imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/Weaver-OB-Bench/checkoutservice/CheckoutService", Method: "PlaceOrder"}).Put(float64(internalLatency.Microseconds()))

	return order, out, nil
}

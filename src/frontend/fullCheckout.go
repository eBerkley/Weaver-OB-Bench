// //go:build full_checkout
// // +build full_checkout

package frontend

import (
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"

	"github.com/eBerkley/Weaver-OB-Bench/checkoutservice"
	"github.com/eBerkley/Weaver-OB-Bench/paymentservice"
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice"
	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	imetrics "github.com/eberkley/weaver/runtime/codegen"
)

func (fe *Server) placeOrderHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	label := imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "placeOrderHandler"}
	concurrency := imetrics.InternalConcurrentMetricsFor(label)
	concurrency.Begin()
	defer func() {
		concurrency.End()
		imetrics.InternalMetricsFor(label).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()
	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	logger.Debug("placing order")

	var (
		email         = r.FormValue("email")
		streetAddress = r.FormValue("street_address")
		zipCode, _    = strconv.ParseInt(r.FormValue("zip_code"), 10, 32)
		city          = r.FormValue("city")
		state         = r.FormValue("state")
		country       = r.FormValue("country")
		ccNumber      = r.FormValue("credit_card_number")
		ccMonth, _    = strconv.ParseInt(r.FormValue("credit_card_expiration_month"), 10, 32)
		ccYear, _     = strconv.ParseInt(r.FormValue("credit_card_expiration_year"), 10, 32)
		ccCVV, _      = strconv.ParseInt(r.FormValue("credit_card_cvv"), 10, 32)
	)
	ordReq := checkoutservice.PlaceOrderRequest{
		Email: email,
		CreditCard: paymentservice.CreditCardInfo{
			Number:          ccNumber,
			ExpirationMonth: time.Month(ccMonth),
			ExpirationYear:  int(ccYear),
			CVV:             int32(ccCVV)},
		UserID:       sessionID(r),
		UserCurrency: currentCurrency(r),
		Address: shippingservice.Address{
			StreetAddress: streetAddress,
			City:          city,
			State:         state,
			ZipCode:       int32(zipCode),
			Country:       country},
	}

	placeOrderTime := time.Now()
	order, recommendations, err := fe.checkoutService.Get().PlaceOrder(r.Context(), ordReq)
	duration += time.Since(placeOrderTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to complete the order: %w", err), http.StatusInternalServerError)
		return
	}
	logger.Info("order placed", "id", order.OrderID)

	totalPaid := order.ShippingCost
	for _, item := range order.Items {
		multPrice := money.MultiplySlow(item.Cost, uint32(item.Item.Quantity))
		totalPaid = money.Must(money.Sum(totalPaid, multPrice))
	}

	currencies, d, err := fe.getCurrencies(r.Context())
	duration += d
	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve currencies: %w", err), http.StatusInternalServerError)
		return
	}
	// productIDs := make([]string, len(order.Items))
	// for i, p := range order.Items {
	// 	productIDs[i] = p.Item.ProductID
	// }
	// recommendations, d, _ := fe.getRecommendations(r.Context(), sessionID(r), productIDs)
	duration += d
	if err := templates.ExecuteTemplate(w, "order", map[string]interface{}{
		"session_id":      sessionID(r),
		"request_id":      r.Context().Value(ctxKeyRequestID{}),
		"hostname":        fe.hostname,
		"user_currency":   currentCurrency(r),
		"show_currency":   false,
		"currencies":      currencies,
		"order":           order,
		"total_paid":      &totalPaid,
		"recommendations": recommendations,
		"platform_css":    fe.platform.css,
		"platform_name":   fe.platform.provider,
		"is_cymbal_brand": isCymbalBrand,
	}); err != nil {
		logger.Error("generate order page", "err", err)
	}
}

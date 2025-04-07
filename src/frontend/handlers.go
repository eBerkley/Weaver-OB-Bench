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

package frontend

import (
	"context"
	"embed"
	"errors"
	"fmt"
	"html/template"
	"log/slog"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/eBerkley/Weaver-OB-Bench/adservice"
	"github.com/eBerkley/Weaver-OB-Bench/cartservice"
	"github.com/eBerkley/Weaver-OB-Bench/checkoutservice"
	"github.com/eBerkley/Weaver-OB-Bench/paymentservice"
	"github.com/eBerkley/Weaver-OB-Bench/productcatalogservice"
	"github.com/eBerkley/Weaver-OB-Bench/shippingservice"
	"github.com/eBerkley/Weaver-OB-Bench/types/money"
	imetrics "github.com/eberkley/weaver/runtime/codegen"
)

const (
	avoidNoopCurrencyConversionRPC = false
)

var (
	isCymbalBrand = strings.ToLower(os.Getenv("CYMBAL_BRANDING")) == "true"

	//go:embed templates/*
	templateFS embed.FS
	templates  = template.Must(template.New("").
			Funcs(template.FuncMap{
			"renderMoney":        renderMoney,
			"renderCurrencyLogo": renderCurrencyLogo,
		}).ParseFS(templateFS, "templates/*.html"))

	allowlistedCurrencies = map[string]bool{
		"USD": true,
		"EUR": true,
		"CAD": true,
		"JPY": true,
		"GBP": true,
		"TRY": true,
	}

	logos = map[string]string{
		"USD": "$",
		"CAD": "$",
		"JPY": "¥",
		"EUR": "€",
		"TRY": "₺",
		"GBP": "£",
	}

	defaultCurrency = "USD"
)

func (fe *Server) homeHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "homeHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	logger.Info("home", "currency", currentCurrency(r))

	currencies, d, err := fe.getCurrencies(r.Context())
	duration += d
	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve currencies: %w", err), http.StatusInternalServerError)
		return
	}
	// Begin fetching list of products from shard
	var products []productcatalogservice.Product

	// We gotta do this first sadly, could be bad if routing table updates mid loop
	fe.catalogMu.RLock()
	repls := fe.catalogReplicas
	table := make([]int, repls)
	for i := 0; i < repls; i++ {
		table[i] = fe.catalogRoutingTable[i]
	}
	fe.catalogMu.RUnlock()

	for shard := 0; shard < repls; shard++ {
		// Routing key that will route to the correct shard.
		key := table[shard]

		listTime := time.Now()
		prods, err := fe.catalogService.Get().ListProducts(r.Context(), key)
		duration += time.Since(listTime)

		if err != nil {
			fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve products: %w", err), http.StatusInternalServerError)
			return
		}

		products = append(products, prods...)
	}

	getCartTime := time.Now()
	cart, err := fe.cartService.Get().GetCart(r.Context(), sessionID(r))
	duration += time.Since(getCartTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve cart: %w", err), http.StatusInternalServerError)
		return
	}

	type productView struct {
		Item  productcatalogservice.Product
		Price money.T
	}
	ps := make([]productView, len(products))
	for i, p := range products {
		convertTime := time.Now()
		price, err := fe.currencyService.Get().Convert(r.Context(), p.PriceUSD, currentCurrency(r))
		duration += time.Since(convertTime)

		if err != nil {
			fe.renderHTTPError(r, w, fmt.Errorf("failed to do currency conversion for product %s: %w", p.ID, err), http.StatusInternalServerError)
			return
		}
		ps[i] = productView{p, price}
	}
	ad, d := fe.chooseAd(r.Context(), []string{}, logger)
	duration += d

	if err := templates.ExecuteTemplate(w, "home", map[string]interface{}{
		"session_id":      sessionID(r),
		"request_id":      r.Context().Value(ctxKeyRequestID{}),
		"hostname":        fe.hostname,
		"user_currency":   currentCurrency(r),
		"show_currency":   true,
		"currencies":      currencies,
		"products":        ps,
		"cart_size":       cartSize(cart),
		"banner_color":    os.Getenv("BANNER_COLOR"),
		"ad":              ad,
		"platform_css":    fe.platform.css,
		"platform_name":   fe.platform.provider,
		"is_cymbal_brand": isCymbalBrand,
	}); err != nil {
		logger.Error("generate home page", "err", err)
	}
}

func (fe *Server) productHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "productHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	_, id := filepath.Split(r.URL.Path)
	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)

	if id == "" {
		fe.renderHTTPError(r, w, errors.New("product id not specified"), http.StatusBadRequest)
		return
	}

	logger.Debug("serving product page", "id", id, "currency", currentCurrency(r))

	fe.catalogMu.RLock()
	shard := productcatalogservice.HashProductID(id, fe.catalogReplicas)
	key := fe.catalogRoutingTable[shard]
	fe.catalogMu.RUnlock()

	getProductTime := time.Now()
	p, err := fe.catalogService.Get().GetProduct(r.Context(), id, key)
	duration += time.Since(getProductTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve product in shard %v: %w", shard, err), http.StatusInternalServerError)
		return
	}

	currencies, d, err := fe.getCurrencies(r.Context())
	duration += d
	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve currencies: %w", err), http.StatusInternalServerError)
		return
	}
	getCartTime := time.Now()
	cart, err := fe.cartService.Get().GetCart(r.Context(), sessionID(r))
	duration += time.Since(getCartTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve cart: %w", err), http.StatusInternalServerError)
		return
	}

	price, d, err := fe.convertCurrency(r.Context(), p.PriceUSD, currentCurrency(r))
	duration += d

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to convert currency: %w", err), http.StatusInternalServerError)
		return
	}

	recommendations, d, err := fe.getRecommendations(r.Context(), sessionID(r), []string{id})
	duration += d

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to get product recommendations: %w", err), http.StatusInternalServerError)
		return
	}

	product := struct {
		Item  productcatalogservice.Product
		Price money.T
	}{p, price}

	ad, d := fe.chooseAd(r.Context(), p.Categories, logger)
	duration += d

	if err := templates.ExecuteTemplate(w, "product", map[string]interface{}{
		"session_id":      sessionID(r),
		"request_id":      r.Context().Value(ctxKeyRequestID{}),
		"hostname":        fe.hostname,
		"ad":              ad,
		"user_currency":   currentCurrency(r),
		"show_currency":   true,
		"currencies":      currencies,
		"product":         product,
		"recommendations": recommendations,
		"cart_size":       cartSize(cart),
		"platform_css":    fe.platform.css,
		"platform_name":   fe.platform.provider,
		"is_cymbal_brand": isCymbalBrand,
	}); err != nil {
		logger.Error("generate product page", "err", err)
	}
}

func (fe *Server) cartHandler(w http.ResponseWriter, r *http.Request) {

	if r.Method == http.MethodGet || r.Method == http.MethodHead {
		fe.viewCartHandler(w, r)
		return
	}
	if r.Method == http.MethodPost {
		fe.addToCartHandler(w, r)
		return
	}
	msg := fmt.Sprintf("method %q not allowed", r.Method)
	http.Error(w, msg, http.StatusMethodNotAllowed)
}

func (fe *Server) addToCartHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration

	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "addToCartHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()
	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)

	quantity, _ := strconv.ParseUint(r.FormValue("quantity"), 10, 32)
	productID := r.FormValue("product_id")
	if productID == "" || quantity == 0 {
		fe.renderHTTPError(r, w, errors.New("invalid form input"), http.StatusBadRequest)
		return
	}
	logger.Debug("adding to cart", "product", productID, "quantity", quantity)

	fe.catalogMu.RLock()
	shard := productcatalogservice.HashProductID(productID, fe.catalogReplicas)
	key := fe.catalogRoutingTable[shard]
	fe.catalogMu.RUnlock()

	getProductTime := time.Now()
	p, err := fe.catalogService.Get().GetProduct(r.Context(), productID, key)
	duration += time.Since(getProductTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve product at shard %v: %w", shard, err), http.StatusInternalServerError)
		return
	}
	addItemTime := time.Now()
	err = fe.cartService.Get().AddItem(r.Context(), sessionID(r), cartservice.CartItem{
		ProductID: p.ID,
		Quantity:  int32(quantity),
	})
	duration += time.Since(addItemTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to add to cart: %w", err), http.StatusInternalServerError)
		return
	}
	w.Header().Set("location", "/cart")
	w.WriteHeader(http.StatusFound)
}

func (fe *Server) emptyCartHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "emptyCartHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	logger.Debug("emptying cart")

	emptyCartTime := time.Now()
	err := fe.cartService.Get().EmptyCart(r.Context(), sessionID(r))
	duration += time.Since(emptyCartTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to empty cart: %w", err), http.StatusInternalServerError)
		return
	}
	w.Header().Set("location", "/")
	w.WriteHeader(http.StatusFound)
}

func (fe *Server) viewCartHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "viewCartHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)

	currencies, d, err := fe.getCurrencies(r.Context())
	duration += d
	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve currencies: %w", err), http.StatusInternalServerError)
		return
	}

	getCartTime := time.Now()
	cart, err := fe.cartService.Get().GetCart(r.Context(), sessionID(r))
	duration += time.Since(getCartTime)

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve cart: %w", err), http.StatusInternalServerError)
		return
	}

	recommendations, d, err := fe.getRecommendations(r.Context(), sessionID(r), cartIDs(cart))
	duration += d

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to get product recommendations: %w", err), http.StatusInternalServerError)
		return
	}

	shippingCost, d, err := fe.getShippingQuote(r.Context(), cart, currentCurrency(r))
	duration += d

	if err != nil {
		fe.renderHTTPError(r, w, fmt.Errorf("failed to get shipping quote: %w", err), http.StatusInternalServerError)
		return
	}

	type cartItemView struct {
		Item     productcatalogservice.Product
		Quantity int32
		Price    *money.T
	}
	items := make([]cartItemView, len(cart))
	totalPrice := money.T{CurrencyCode: currentCurrency(r)}
	for i, item := range cart {

		fe.catalogMu.RLock()
		shard := productcatalogservice.HashProductID(item.ProductID, fe.catalogReplicas)
		key := fe.catalogRoutingTable[shard]
		fe.catalogMu.RUnlock()

		getProductTime := time.Now()
		p, err := fe.catalogService.Get().GetProduct(r.Context(), item.ProductID, key)
		duration += time.Since(getProductTime)

		if err != nil {
			fe.renderHTTPError(r, w, fmt.Errorf("could not retrieve product #%s at %v: %w", item.ProductID, shard, err), http.StatusInternalServerError)
			return
		}

		price, d, err := fe.convertCurrency(r.Context(), p.PriceUSD, currentCurrency(r))
		duration += d
		if err != nil {
			fe.renderHTTPError(r, w, fmt.Errorf("could not convert currency for product #%s: %w", item.ProductID, err), http.StatusInternalServerError)
			return
		}

		multPrice := money.MultiplySlow(price, uint32(item.Quantity))
		items[i] = cartItemView{
			Item:     p,
			Quantity: item.Quantity,
			Price:    &multPrice}
		totalPrice = money.Must(money.Sum(totalPrice, multPrice))
	}
	totalPrice = money.Must(money.Sum(totalPrice, shippingCost))
	year := time.Now().Year()

	if err := templates.ExecuteTemplate(w, "cart", map[string]interface{}{
		"session_id":       sessionID(r),
		"request_id":       r.Context().Value(ctxKeyRequestID{}),
		"hostname":         fe.hostname,
		"user_currency":    currentCurrency(r),
		"currencies":       currencies,
		"recommendations":  recommendations,
		"cart_size":        cartSize(cart),
		"shipping_cost":    shippingCost,
		"show_currency":    true,
		"total_cost":       totalPrice,
		"items":            items,
		"expiration_years": []int{year, year + 1, year + 2, year + 3, year + 4},
		"platform_css":     fe.platform.css,
		"platform_name":    fe.platform.provider,
		"is_cymbal_brand":  isCymbalBrand,
	}); err != nil {
		logger.Error("generate cart page", "err", err)
	}
}

func (fe *Server) placeOrderHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "placeOrderHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
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
	order, err := fe.checkoutService.Get().PlaceOrder(r.Context(), ordReq)
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
	productIDs := make([]string, len(order.Items))
	for i, p := range order.Items {
		productIDs[i] = p.Item.ProductID
	}
	recommendations, d, _ := fe.getRecommendations(r.Context(), sessionID(r), productIDs)
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

func (fe *Server) logoutHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "logoutHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	logger.Debug("logging out")
	for _, c := range r.Cookies() {
		c.Expires = time.Now().Add(-time.Hour * 24 * 365)
		c.MaxAge = -1
		http.SetCookie(w, c)
	}
	w.Header().Set("Location", "/")
	w.WriteHeader(http.StatusFound)
}

func (fe *Server) setCurrencyHandler(w http.ResponseWriter, r *http.Request) {
	initTime := time.Now()
	var duration time.Duration
	defer func() {

		imetrics.InternalMetricsFor(imetrics.InternalMethodLabels{Component: "github.com/eBerkley/weaver/Main", Method: "setCurrencyHandler"}).Put(float64((time.Since(initTime) - duration).Microseconds()))
	}()

	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	cur := r.FormValue("currency_code")
	logger.Debug("setting currency", "curr.new", cur, "curr.old", currentCurrency(r))

	if cur != "" {
		http.SetCookie(w, &http.Cookie{
			Name:   cookieCurrency,
			Value:  cur,
			MaxAge: cookieMaxAge,
		})
	}
	referer := r.Header.Get("referer")
	if referer == "" {
		referer = "/"
	}
	w.Header().Set("Location", referer)
	w.WriteHeader(http.StatusFound)
}

// chooseAd queries for advertisements available and randomly chooses one, if
// available. It ignores the error retrieving the ad since it is not critical.
func (fe *Server) chooseAd(ctx context.Context, ctxKeys []string, logger *slog.Logger) (*adservice.Ad, time.Duration) {
	var duration time.Duration

	ctx, cancel := context.WithTimeout(ctx, time.Millisecond*100)
	defer cancel()
	getAdsTime := time.Now()
	ads, err := fe.adService.Get().GetAds(ctx, ctxKeys)
	duration += time.Since(getAdsTime)

	if err != nil {
		logger.Error("failed to retrieve ads", "err", err)
		return nil, duration
	}
	return &ads[0], duration
	// return &ads[rand.Intn(len(ads))]
}

func (fe *Server) getCurrencies(ctx context.Context) ([]string, time.Duration, error) {
	var duration time.Duration

	getSuppTime := time.Now()
	codes, err := fe.currencyService.Get().GetSupportedCurrencies(ctx)
	duration += time.Since(getSuppTime)

	if err != nil {
		return nil, duration, err
	}
	var out []string
	for _, c := range codes {
		if _, ok := allowlistedCurrencies[c]; ok {
			out = append(out, c)
		}
	}
	return out, duration, nil
}

func (fe *Server) convertCurrency(ctx context.Context, money money.T, currency string) (money.T, time.Duration, error) {
	var duration time.Duration
	if avoidNoopCurrencyConversionRPC && money.CurrencyCode == currency {
		return money, duration, nil
	}
	convertTime := time.Now()
	money, err := fe.currencyService.Get().Convert(ctx, money, currency)
	duration += time.Since(convertTime)
	return money, duration, err
}

func (fe *Server) getShippingQuote(ctx context.Context, items []cartservice.CartItem, currency string) (money.T, time.Duration, error) {
	var duration time.Duration
	getQuoteTime := time.Now()
	quote, err := fe.shippingService.Get().GetQuote(ctx, shippingservice.Address{}, items)
	duration += time.Since(getQuoteTime)

	if err != nil {
		return money.T{}, duration, err
	}
	money, d, err := fe.convertCurrency(ctx, quote, currency)
	duration += d
	return money, duration, err
}

func (fe *Server) getRecommendations(ctx context.Context, userID string, productIDs []string) ([]productcatalogservice.Product, time.Duration, error) {
	var duration time.Duration

	listRecsTime := time.Now()
	recommendationIDs, err := fe.recommendationService.Get().ListRecommendations(ctx, userID, productIDs)
	duration += time.Since(listRecsTime)

	if err != nil {
		return nil, duration, err
	}

	out := make([]productcatalogservice.Product, 0, len(recommendationIDs))

	fe.catalogMu.RLock()
	productShardMap := make([][]string, fe.catalogReplicas)
	repls := fe.catalogReplicas
	table := make([]int, repls)
	for i := 0; i < repls; i++ {
		table[i] = fe.catalogRoutingTable[i]
	}
	fe.catalogMu.RUnlock()

	for _, id := range recommendationIDs {
		shard := productcatalogservice.HashProductID(id, repls)
		productShardMap[shard] = append(productShardMap[shard], id)
	}

	// Because of the large number of goroutines active in main, we send an RPC to each replica serially, rather than concurrently.
	for shard := 0; shard < repls; shard++ {

		if len(productShardMap[shard]) == 0 {
			continue
		}

		key := table[shard]

		getProductsTime := time.Now()
		prods, err := fe.catalogService.Get().
			GetProducts(ctx, productShardMap[shard], key)
		duration += time.Since(getProductsTime)

		if err != nil {
			return nil, duration, fmt.Errorf("failed to get recommended product info at shard %v: %w", shard, err)
		}
		out = append(out, prods...)
	}
	if len(out) > 4 {
		out = out[:4] // take only first four to fit the UI
	}
	return out, duration, err
}

func (fe *Server) renderHTTPError(r *http.Request, w http.ResponseWriter, err error, code int) {
	logger := r.Context().Value(ctxKeyLogger{}).(*slog.Logger)
	logger.Error("request error", "err", err)
	errMsg := fmt.Sprintf("%+v", err)

	w.WriteHeader(code)

	if templateErr := templates.ExecuteTemplate(w, "error", map[string]interface{}{
		"session_id":  sessionID(r),
		"request_id":  r.Context().Value(ctxKeyRequestID{}),
		"hostname":    fe.hostname,
		"error":       errMsg,
		"status_code": code,
		"status":      http.StatusText(code),
	}); templateErr != nil {
		logger.Error("generate error page", "err", templateErr)
	}
}

func currentCurrency(r *http.Request) string {
	c, _ := r.Cookie(cookieCurrency)
	if c != nil {
		return c.Value
	}
	return defaultCurrency
}

func sessionID(r *http.Request) string {
	v := r.Context().Value(ctxKeySessionID{})
	if v != nil {
		return v.(string)
	}
	return ""
}

func cartIDs(c []cartservice.CartItem) []string {
	out := make([]string, len(c))
	for i, v := range c {
		out[i] = v.ProductID
	}
	return out
}

// get total # of items in cart
func cartSize(c []cartservice.CartItem) int {
	cartSize := 0
	for _, item := range c {
		cartSize += int(item.Quantity)
	}
	return cartSize
}

func renderMoney(m money.T) string {
	currencyLogo := renderCurrencyLogo(m.CurrencyCode)

	// return fmt.Sprintf("%s%d.%02d", currencyLogo, m.Units, m.Nanos/10000000)

	return fmt.Sprintf("%s%d.%02.f", currencyLogo, m.Units, math.Round(float64(m.Nanos)/10000000.0))
}

func renderCurrencyLogo(currencyCode string) string {

	logo := "$" //default
	if val, ok := logos[currencyCode]; ok {
		logo = val
	}
	return logo
}

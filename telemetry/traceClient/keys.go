package traceclient

import v1 "go.opentelemetry.io/proto/otlp/trace/v1"

type EventType string

const (
	EventRedisRStart    EventType = "Redis-R-Start"
	EventRedisREnd      EventType = "Redis-R-End"
	EventRedisWStart    EventType = "Redis-W-Start"
	EventRedisWEnd      EventType = "Redis-W-End"
	EventMongoStart     EventType = "Mongo-Start"
	EventMongoEnd       EventType = "Mongo-End"
	EventRandomKeyStart EventType = "RandomKey-Start"
	EventRandomKeyEnd   EventType = "RandomKey-End"
)

var (
	_event_pairs = map[EventType]EventType{
		EventRedisRStart:    EventRedisREnd,
		EventRedisREnd:      EventRedisRStart,
		EventRedisWStart:    EventRedisWEnd,
		EventRedisWEnd:      EventRedisWStart,
		EventMongoStart:     EventMongoEnd,
		EventMongoEnd:       EventMongoStart,
		EventRandomKeyStart: EventRandomKeyEnd,
		EventRandomKeyEnd:   EventRandomKeyStart,
	}
	_event_starts = map[EventType]bool{
		EventRedisRStart:    true,
		EventRedisWStart:    true,
		EventMongoStart:     true,
		EventRandomKeyStart: true,
	}
)

func (e EventType) GetPair() EventType { return _event_pairs[e] }
func (e EventType) IsStart() bool      { return _event_starts[e] }
func (e EventType) String() string {
	if e.IsStart() {
		return string(e)[:len(e)-len("-Start")]
	} else {
		return string(e)[:len(e)-len("-End")]
	}
}

type Type string

const (
	TypeClient Type = "client"
	TypeServer Type = "server"
)

func GetType(kind v1.Span_SpanKind) Type {
	if kind == v1.Span_SPAN_KIND_CLIENT {
		return TypeClient
	}
	return TypeServer
}

type Operation string

const (
	AGetAds Operation = "adservice.AdService.GetAds"

	CaGetCart   Operation = "cartservice.CartService.GetCart"
	CaEmptyCart Operation = "cartservice.CartService.EmptyCart"
	CaAddItem   Operation = "cartservice.CartService.AddItem"

	ChPlaceOrder Operation = "checkoutservice.CheckoutService.PlaceOrder"

	CuGetSupportedCurrencies Operation = "currencyservice.CurrencyService.GetSupportedCurrencies"
	CuConvert                Operation = "currencyservice.CurrencyService.Convert"

	ESendOrderConfirmation Operation = "emailservice.EmailService.SendOrderConfirmation"

	PaCharge Operation = "paymentservice.PaymentService.Charge"

	PrListProducts   Operation = "productcatalogservice.ProductCatalogService.ListProducts"
	PrGetProduct     Operation = "productcatalogservice.ProductCatalogService.GetProduct"
	PrGetProducts    Operation = "productcatalogservice.ProductCatalogService.GetProducts"
	PrSearchProducts Operation = "productcatalogservice.ProductCatalogService.SearchProducts"

	RListRecommendations Operation = "recommendationservice.RecService.ListRecommendations"

	ShGetQuote  Operation = "shippingservice.ShippingService.GetQuote"
	ShShipOrder Operation = "shippingservice.ShippingService.ShipOrder"

	MProduct     Operation = "product"
	MCart        Operation = "cart"
	MCartEmpty   Operation = "cart_empty"
	MHome        Operation = "home"
	MSetCurrency Operation = "setcurrency"
	MCheckout    Operation = "cart_checkout"
)

type Method string

const (
	MethodIndex       Method = "index"
	MethodSetCurrency Method = "setCurrency"
	MethodBrowse      Method = "browse"
	MethodViewCart    Method = "viewCart"
	MethodAddToCart   Method = "addToCart"
	MethodEmptyCart   Method = "emptyCart"
	MethodCheckout    Method = "checkout"
)

func GetMethod(op Operation, reqMethod string) Method {
	switch op {
	case MProduct:
		if reqMethod == "GET" {
			return MethodBrowse
		}
	case MCart:
		switch reqMethod {
		case "GET":
			return MethodViewCart
		case "POST":
			return MethodAddToCart
		}
	case MHome:
		return MethodIndex
	case MSetCurrency:
		return MethodSetCurrency
	case MCheckout:
		if reqMethod == "POST" {
			return MethodCheckout
		}
	case MCartEmpty:
		return MethodEmptyCart
	}
	return "" // Error!!! Whatever
}

var _is_main_operation = map[Operation]bool{
	MProduct:     true,
	MCart:        true,
	MCartEmpty:   true,
	MHome:        true,
	MCheckout:    true,
	MSetCurrency: true,
}

func (o Operation) IsMain() bool {
	return _is_main_operation[o]
}

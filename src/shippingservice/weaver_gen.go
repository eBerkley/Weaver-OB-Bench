// Code generated by "weaver generate". DO NOT EDIT.
//go:build !ignoreWeaverGen

package shippingservice

import (
	"context"
	"errors"
	"fmt"
	"github.com/ServiceWeaver/onlineboutique/cartservice"
	"github.com/ServiceWeaver/onlineboutique/types/money"
	"github.com/ServiceWeaver/weaver"
	"github.com/ServiceWeaver/weaver/runtime/codegen"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
	"reflect"
)

func init() {
	codegen.Register(codegen.Registration{
		Name:  "github.com/ServiceWeaver/onlineboutique/shippingservice/ShippingService",
		Iface: reflect.TypeOf((*ShippingService)(nil)).Elem(),
		Impl:  reflect.TypeOf(impl{}),
		LocalStubFn: func(impl any, caller string, tracer trace.Tracer) any {
			return shippingService_local_stub{impl: impl.(ShippingService), tracer: tracer, getQuoteMetrics: codegen.MethodMetricsFor(codegen.MethodLabels{Caller: caller, Component: "github.com/ServiceWeaver/onlineboutique/shippingservice/ShippingService", Method: "GetQuote", Remote: false, Generated: true}), shipOrderMetrics: codegen.MethodMetricsFor(codegen.MethodLabels{Caller: caller, Component: "github.com/ServiceWeaver/onlineboutique/shippingservice/ShippingService", Method: "ShipOrder", Remote: false, Generated: true})}
		},
		ClientStubFn: func(stub codegen.Stub, caller string) any {
			return shippingService_client_stub{stub: stub, getQuoteMetrics: codegen.MethodMetricsFor(codegen.MethodLabels{Caller: caller, Component: "github.com/ServiceWeaver/onlineboutique/shippingservice/ShippingService", Method: "GetQuote", Remote: true, Generated: true}), shipOrderMetrics: codegen.MethodMetricsFor(codegen.MethodLabels{Caller: caller, Component: "github.com/ServiceWeaver/onlineboutique/shippingservice/ShippingService", Method: "ShipOrder", Remote: true, Generated: true})}
		},
		ServerStubFn: func(impl any, addLoad func(uint64, float64)) codegen.Server {
			return shippingService_server_stub{impl: impl.(ShippingService), addLoad: addLoad}
		},
		ReflectStubFn: func(caller func(string, context.Context, []any, []any) error) any {
			return shippingService_reflect_stub{caller: caller}
		},
		RefData: "",
	})
}

// weaver.InstanceOf checks.
var _ weaver.InstanceOf[ShippingService] = (*impl)(nil)

// weaver.Router checks.
var _ weaver.Unrouted = (*impl)(nil)

// Local stub implementations.

type shippingService_local_stub struct {
	impl             ShippingService
	tracer           trace.Tracer
	getQuoteMetrics  *codegen.MethodMetrics
	shipOrderMetrics *codegen.MethodMetrics
}

// Check that shippingService_local_stub implements the ShippingService interface.
var _ ShippingService = (*shippingService_local_stub)(nil)

func (s shippingService_local_stub) GetQuote(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 money.T, err error) {
	// Update metrics.
	begin := s.getQuoteMetrics.Begin()
	defer func() { s.getQuoteMetrics.End(begin, err != nil, 0, 0) }()
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		// Create a child span for this method.
		ctx, span = s.tracer.Start(ctx, "shippingservice.ShippingService.GetQuote", trace.WithSpanKind(trace.SpanKindInternal))
		defer func() {
			if err != nil {
				span.RecordError(err)
				span.SetStatus(codes.Error, err.Error())
			}
			span.End()
		}()
	}

	return s.impl.GetQuote(ctx, a0, a1)
}

func (s shippingService_local_stub) ShipOrder(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 string, err error) {
	// Update metrics.
	begin := s.shipOrderMetrics.Begin()
	defer func() { s.shipOrderMetrics.End(begin, err != nil, 0, 0) }()
	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		// Create a child span for this method.
		ctx, span = s.tracer.Start(ctx, "shippingservice.ShippingService.ShipOrder", trace.WithSpanKind(trace.SpanKindInternal))
		defer func() {
			if err != nil {
				span.RecordError(err)
				span.SetStatus(codes.Error, err.Error())
			}
			span.End()
		}()
	}

	return s.impl.ShipOrder(ctx, a0, a1)
}

// Client stub implementations.

type shippingService_client_stub struct {
	stub             codegen.Stub
	getQuoteMetrics  *codegen.MethodMetrics
	shipOrderMetrics *codegen.MethodMetrics
}

// Check that shippingService_client_stub implements the ShippingService interface.
var _ ShippingService = (*shippingService_client_stub)(nil)

func (s shippingService_client_stub) GetQuote(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 money.T, err error) {
	// Update metrics.
	var requestBytes, replyBytes int
	begin := s.getQuoteMetrics.Begin()
	defer func() { s.getQuoteMetrics.End(begin, err != nil, requestBytes, replyBytes) }()

	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		// Create a child span for this method.
		ctx, span = s.stub.Tracer().Start(ctx, "shippingservice.ShippingService.GetQuote", trace.WithSpanKind(trace.SpanKindClient))
	}

	defer func() {
		// Catch and return any panics detected during encoding/decoding/rpc.
		if err == nil {
			err = codegen.CatchPanics(recover())
			if err != nil {
				err = errors.Join(weaver.RemoteCallError, err)
			}
		}

		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		span.End()

	}()

	// Encode arguments.
	enc := codegen.NewEncoder()
	(a0).WeaverMarshal(enc)
	serviceweaver_enc_slice_CartItem_7164ef85(enc, a1)
	var shardKey uint64

	// Call the remote method.
	requestBytes = len(enc.Data())
	var results []byte
	results, err = s.stub.Run(ctx, 0, enc.Data(), shardKey)
	replyBytes = len(results)
	if err != nil {
		err = errors.Join(weaver.RemoteCallError, err)
		return
	}

	// Decode the results.
	dec := codegen.NewDecoder(results)
	(&r0).WeaverUnmarshal(dec)
	err = dec.Error()
	return
}

func (s shippingService_client_stub) ShipOrder(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 string, err error) {
	// Update metrics.
	var requestBytes, replyBytes int
	begin := s.shipOrderMetrics.Begin()
	defer func() { s.shipOrderMetrics.End(begin, err != nil, requestBytes, replyBytes) }()

	span := trace.SpanFromContext(ctx)
	if span.SpanContext().IsValid() {
		// Create a child span for this method.
		ctx, span = s.stub.Tracer().Start(ctx, "shippingservice.ShippingService.ShipOrder", trace.WithSpanKind(trace.SpanKindClient))
	}

	defer func() {
		// Catch and return any panics detected during encoding/decoding/rpc.
		if err == nil {
			err = codegen.CatchPanics(recover())
			if err != nil {
				err = errors.Join(weaver.RemoteCallError, err)
			}
		}

		if err != nil {
			span.RecordError(err)
			span.SetStatus(codes.Error, err.Error())
		}
		span.End()

	}()

	// Encode arguments.
	enc := codegen.NewEncoder()
	(a0).WeaverMarshal(enc)
	serviceweaver_enc_slice_CartItem_7164ef85(enc, a1)
	var shardKey uint64

	// Call the remote method.
	requestBytes = len(enc.Data())
	var results []byte
	results, err = s.stub.Run(ctx, 1, enc.Data(), shardKey)
	replyBytes = len(results)
	if err != nil {
		err = errors.Join(weaver.RemoteCallError, err)
		return
	}

	// Decode the results.
	dec := codegen.NewDecoder(results)
	r0 = dec.String()
	err = dec.Error()
	return
}

// Note that "weaver generate" will always generate the error message below.
// Everything is okay. The error message is only relevant if you see it when
// you run "go build" or "go run".
var _ codegen.LatestVersion = codegen.Version[[0][24]struct{}](`

ERROR: You generated this file with 'weaver generate' v0.24.5 (codegen
version v0.24.0). The generated code is incompatible with the version of the
github.com/ServiceWeaver/weaver module that you're using. The weaver module
version can be found in your go.mod file or by running the following command.

    go list -m github.com/ServiceWeaver/weaver

We recommend updating the weaver module and the 'weaver generate' command by
running the following.

    go get github.com/ServiceWeaver/weaver@latest
    go install github.com/ServiceWeaver/weaver/cmd/weaver@latest

Then, re-run 'weaver generate' and re-build your code. If the problem persists,
please file an issue at https://github.com/ServiceWeaver/weaver/issues.

`)

// Server stub implementations.

type shippingService_server_stub struct {
	impl    ShippingService
	addLoad func(key uint64, load float64)
}

// Check that shippingService_server_stub implements the codegen.Server interface.
var _ codegen.Server = (*shippingService_server_stub)(nil)

// GetStubFn implements the codegen.Server interface.
func (s shippingService_server_stub) GetStubFn(method string) func(ctx context.Context, args []byte) ([]byte, error) {
	switch method {
	case "GetQuote":
		return s.getQuote
	case "ShipOrder":
		return s.shipOrder
	default:
		return nil
	}
}

func (s shippingService_server_stub) getQuote(ctx context.Context, args []byte) (res []byte, err error) {
	// Catch and return any panics detected during encoding/decoding/rpc.
	defer func() {
		if err == nil {
			err = codegen.CatchPanics(recover())
		}
	}()

	// Decode arguments.
	dec := codegen.NewDecoder(args)
	var a0 Address
	(&a0).WeaverUnmarshal(dec)
	var a1 []cartservice.CartItem
	a1 = serviceweaver_dec_slice_CartItem_7164ef85(dec)

	// TODO(rgrandl): The deferred function above will recover from panics in the
	// user code: fix this.
	// Call the local method.
	r0, appErr := s.impl.GetQuote(ctx, a0, a1)

	// Encode the results.
	enc := codegen.NewEncoder()
	(r0).WeaverMarshal(enc)
	enc.Error(appErr)
	return enc.Data(), nil
}

func (s shippingService_server_stub) shipOrder(ctx context.Context, args []byte) (res []byte, err error) {
	// Catch and return any panics detected during encoding/decoding/rpc.
	defer func() {
		if err == nil {
			err = codegen.CatchPanics(recover())
		}
	}()

	// Decode arguments.
	dec := codegen.NewDecoder(args)
	var a0 Address
	(&a0).WeaverUnmarshal(dec)
	var a1 []cartservice.CartItem
	a1 = serviceweaver_dec_slice_CartItem_7164ef85(dec)

	// TODO(rgrandl): The deferred function above will recover from panics in the
	// user code: fix this.
	// Call the local method.
	r0, appErr := s.impl.ShipOrder(ctx, a0, a1)

	// Encode the results.
	enc := codegen.NewEncoder()
	enc.String(r0)
	enc.Error(appErr)
	return enc.Data(), nil
}

// Reflect stub implementations.

type shippingService_reflect_stub struct {
	caller func(string, context.Context, []any, []any) error
}

// Check that shippingService_reflect_stub implements the ShippingService interface.
var _ ShippingService = (*shippingService_reflect_stub)(nil)

func (s shippingService_reflect_stub) GetQuote(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 money.T, err error) {
	err = s.caller("GetQuote", ctx, []any{a0, a1}, []any{&r0})
	return
}

func (s shippingService_reflect_stub) ShipOrder(ctx context.Context, a0 Address, a1 []cartservice.CartItem) (r0 string, err error) {
	err = s.caller("ShipOrder", ctx, []any{a0, a1}, []any{&r0})
	return
}

// AutoMarshal implementations.

var _ codegen.AutoMarshal = (*Address)(nil)

type __is_Address[T ~struct {
	weaver.AutoMarshal
	StreetAddress string
	City          string
	State         string
	Country       string
	ZipCode       int32
}] struct{}

var _ __is_Address[Address]

func (x *Address) WeaverMarshal(enc *codegen.Encoder) {
	if x == nil {
		panic(fmt.Errorf("Address.WeaverMarshal: nil receiver"))
	}
	enc.String(x.StreetAddress)
	enc.String(x.City)
	enc.String(x.State)
	enc.String(x.Country)
	enc.Int32(x.ZipCode)
}

func (x *Address) WeaverUnmarshal(dec *codegen.Decoder) {
	if x == nil {
		panic(fmt.Errorf("Address.WeaverUnmarshal: nil receiver"))
	}
	x.StreetAddress = dec.String()
	x.City = dec.String()
	x.State = dec.String()
	x.Country = dec.String()
	x.ZipCode = dec.Int32()
}

// Encoding/decoding implementations.

func serviceweaver_enc_slice_CartItem_7164ef85(enc *codegen.Encoder, arg []cartservice.CartItem) {
	if arg == nil {
		enc.Len(-1)
		return
	}
	enc.Len(len(arg))
	for i := 0; i < len(arg); i++ {
		(arg[i]).WeaverMarshal(enc)
	}
}

func serviceweaver_dec_slice_CartItem_7164ef85(dec *codegen.Decoder) []cartservice.CartItem {
	n := dec.Len()
	if n == -1 {
		return nil
	}
	res := make([]cartservice.CartItem, n)
	for i := 0; i < n; i++ {
		(&res[i]).WeaverUnmarshal(dec)
	}
	return res
}

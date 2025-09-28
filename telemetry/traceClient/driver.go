package traceclient

import (
	"context"
	"fmt"
	"io"
	"os"
	"telCol/jaeger"
	"time"

	v1 "go.opentelemetry.io/proto/otlp/trace/v1"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (c *TraceClient) addSpan(otlpSpan *v1.Span) {
	traceID := fmt.Sprintf("%x", otlpSpan.TraceId)
	spanID := fmt.Sprintf("%x", otlpSpan.SpanId)

	if t, ok := c.traces[traceID]; ok {
		if t.spans[spanID] != nil {
			return
		}
	}

	span := &Span{
		t: GetType(otlpSpan.Kind),
		// parent:    parentSpan,
		trace:     c.traces[traceID],
		children:  make(map[string]*Span),
		operation: Operation(otlpSpan.Name),
		events:    make(map[EventType]*Event),
		timestamp: time.Unix(0, int64(otlpSpan.StartTimeUnixNano)),
		duration:  time.Duration(otlpSpan.EndTimeUnixNano - otlpSpan.StartTimeUnixNano),
	}

	trace, ok := c.traces[traceID]
	if !ok {
		trace = &Trace{
			traceID: traceID,
			spans:   make(map[string]*Span),
		}
		c.traces[traceID] = trace
	}

	var parentSpan *Span
	if otlpSpan.ParentSpanId != nil {
		pid := fmt.Sprintf("%x", otlpSpan.ParentSpanId)
		parentSpan = c.traces[traceID].spans[pid]
	}

	span.parent = parentSpan

	trace.spans[spanID] = span
	trace.lastUpdated = time.Now()

	// Set trace attributes using the root span.
	if span.operation.IsMain() {
		var httpMethod string
		for _, kv := range otlpSpan.Attributes {
			if kv.Key == "http.request.method" {
				httpMethod = kv.Value.GetStringValue()
				break
			}
		}
		if httpMethod == "" {
			trace.method = "UNKNOWN"
		} else {
			trace.method = GetMethod(span.operation, httpMethod)
		}

		trace.duration = span.duration
		trace.timestamp = span.timestamp
		trace.root = span
	}

	// only applies to productcatalogservice atm
	for _, event := range otlpSpan.Events {

		et := EventType(event.Name)
		// If the event type is invalid
		if et.GetPair() == "" {
			continue
		}

		if et.IsStart() {

			ev, ok := span.events[et]

			if !ok {
				ev = &Event{
					timestamp: time.Unix(0, int64(event.TimeUnixNano)),
				}
				span.events[et] = ev
			} else {
				ev.duration = ev.timestamp.Sub(time.Unix(0, int64(event.TimeUnixNano)))
				ev.timestamp = time.Unix(0, int64(event.TimeUnixNano))
			}

		} else {

			ev, ok := span.events[et.GetPair()]

			if !ok {
				ev = &Event{
					timestamp: time.Unix(0, int64(event.TimeUnixNano)),
				}
				span.events[et] = ev
			} else {
				ev.duration = time.Unix(0, int64(event.TimeUnixNano)).Sub(ev.timestamp)
				// ev.duration = ev.timestamp.Sub(time.Unix(0, int64(event.TimeUnixNano)))
				// ev.timestamp = time.Unix(0, int64(event.TimeUnixNano))
			}

		}

	}
}

func (c *TraceClient) GetTraces(ctx context.Context) error {
	// We intentionally lag 30 seconds behind
	newPrevTimestamp := timestamppb.New(time.Now().Add(-30 * time.Second))

	req := &jaeger.FindTracesRequest{
		Query: &jaeger.TraceQueryParameters{
			StartTimeMin: timestamppb.New(c.prevTimestamp.AsTime().Add(-5 * time.Second)),
			StartTimeMax: newPrevTimestamp,
			ServiceName:  "ob",
			SearchDepth:  100,
		},
	}

	c.prevTimestamp = newPrevTimestamp

	stream, err := c.client.FindTraces(ctx, req)
	if err != nil {
		return fmt.Errorf("jaegerClient.FindTraces(): %w", err)
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	for {
		res, err := stream.Recv()
		if err == io.EOF {
			fmt.Fprintf(os.Stderr, "FindTraces call complete. queue len: %v\n", len(c.traces))
			break
		}
		if err != nil {
			return fmt.Errorf("FindTraces().Recv(): %w", err)
		}

		spans := res.GetResourceSpans()
		for _, rSpan := range spans {
			for _, sSpan := range rSpan.ScopeSpans {
				for _, span := range sSpan.Spans {
					c.addSpan(span)
				}
			}
		}
	}
	return nil
}

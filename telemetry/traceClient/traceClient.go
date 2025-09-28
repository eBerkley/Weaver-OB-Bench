package traceclient

import (
	"context"
	"fmt"
	"io"
	"sync"
	"telCol/jaeger"
	"time"

	"google.golang.org/protobuf/types/known/timestamppb"
)

type TraceClient struct {
	client jaeger.QueryServiceClient

	prevTimestamp *timestamppb.Timestamp

	mu     sync.Mutex
	traces map[string]*Trace // traceID -> Trace
}

func NewClient(jaegerClient jaeger.QueryServiceClient) *TraceClient {
	return &TraceClient{
		client:        jaegerClient,
		prevTimestamp: timestamppb.New(timestamppb.Now().AsTime().Add(-10 * time.Minute)), // 10 minutes ago
		traces:        make(map[string]*Trace),
	}
}

func (c *TraceClient) Start(w io.Writer, ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	go c.Dumper(w, ctx)
	err := c.Fetcher(ctx)
	cancel()
	return err
}

func (c *TraceClient) DumpTraces(w io.Writer, mandatory bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	twoMinsAgo := time.Now().Add(-2 * time.Minute)
	if mandatory {
		fmt.Fprintf(w, "Warning: dumping all traces. data may be incomplete. \n")
	}

	for _, trace := range c.traces {
		if mandatory || trace.lastUpdated.Before(twoMinsAgo) {
			trace.Print(w)
			delete(c.traces, trace.traceID)
		}
	}
}

func (c *TraceClient) Fetcher(ctx context.Context) error {
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
			if err := c.GetTraces(ctx); err != nil {
				return err
			}
			time.Sleep(15 * time.Second)
		}
	}
}

func (c *TraceClient) Dumper(w io.Writer, ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		default:
			c.DumpTraces(w, false)
		}

		time.Sleep(30 * time.Second)

	}
}

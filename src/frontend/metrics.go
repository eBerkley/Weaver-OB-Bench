package frontend

import (
	"time"

	"github.com/ServiceWeaver/weaver/metrics"
)

type label struct {
	Users string
}

var (
	hist = metrics.NewHistogramMap[label](
		"latency",
		"Histogram for latency, mapped to the user count sent by the load generator.",
		metrics.NonNegativeBuckets,
	)
)

func TrackReqLatency(userCount string) func() {
	if userCount == "0" {
		return func() {}
	}

	t := time.Now()

	return func() {
		h := hist.Get(label{Users: userCount})
		h.Put(float64(time.Since(t)))
	}
}

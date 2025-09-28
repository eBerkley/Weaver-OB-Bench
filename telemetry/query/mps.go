package query

import (
	"fmt"
	"net/url"
	"strconv"
)

// __name__: serviceweaver_method_count
// caller: <canonical name>
// component <canonical name>
// instance: <ip address>
// job: <serviceweaver>
// method: Intf method name
// remote: bool
// generated: true
// serviceweaver_node: node name (TODO: maybe look into messing with this)

// histogram_quantile(0.99, sum by (le, component, method, remote) (rate(serviceweaver_method_latency_micros_bucket[30s])))

// serviceweaver_method_latency_micros_bucket{component!~.*\"Control\"}

var (
	QUERY_MPS = PROM_BASE_QUERY + url.QueryEscape(
		fmt.Sprintf("rate(serviceweaver_method_count{component!~.*\"Control\"}[%s])", RATE_WINDOW),
	)
)

type MethodMetricResult struct {
	Component string `json:"component"`
	Method    string `json:"method"`
	Remote    bool   `json:"remote"`
}

// conv: map[canonical name]abbr
func (mmr *MethodMetricResult) Key(conv map[string]string) string {
	prefix := "L"
	if mmr.Remote {
		prefix = "R"
	}

	return fmt.Sprintf("(%s).%s.%s", prefix, conv[mmr.Component], mmr.Method)
}

type MethodMetrics BaseKeyValResp[MethodMetricResult]

// conv: map[canonical name]abbr
func (mm *MethodMetrics) GetMetrics(conv map[string]string) map[string]float32 {
	metMap := make(map[string]float32)
	for _, m := range mm.Data.Result {
		k := m.Metric.Key(conv)
		v, err := strconv.ParseFloat(m.GetValue(), 32)
		if err != nil {
			fmt.Printf("Warning! GetMetrics(%v) returned non-float value %v", k, m.GetValue())
			v = -1.0
		}
		metMap[k] = float32(v)
	}

	return metMap
}
